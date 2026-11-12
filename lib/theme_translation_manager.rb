# frozen_string_literal: true

class ThemeTranslationManager
  include ActiveModel::Serialization
  attr_reader :key, :default, :theme

  SITE_TEXT_ID_PATTERN = /\Ajs\.theme_translations\.(-?\d+)\.(.+)\z/

  def self.find_site_text(id, locale:)
    match = SITE_TEXT_ID_PATTERN.match(id)
    return unless match

    I18n.with_locale(locale) do
      theme = Theme.includes(:locale_fields, :theme_translation_overrides).find_by(id: match[1])
      theme&.translations&.find { |entry| entry.key == match[2] }
    end
  end

  def self.search_site_texts(
    query,
    locale:,
    theme: nil,
    overridden: false,
    outdated: false,
    untranslated: false,
    only_selected_locale: false
  )
    return [] if outdated || (untranslated && locale.to_s == "en")

    regexp = I18n::Backend::DiscourseI18n.create_search_regexp(query)
    themes = Theme.includes(:locale_fields, :theme_translation_overrides)
    themes = themes.where(id: theme.id) if theme
    I18n.with_locale(locale) do
      themes.flat_map do |selected_theme|
        english_entries = I18n.with_locale(:en) { selected_theme.translations.to_a.index_by(&:key) }
        translated_keys = locale_translation_keys(selected_theme, locale:) if untranslated
        selected_theme.translations.filter_map do |entry|
          next if overridden && !entry.has_record?
          next if untranslated && (entry.has_record? || translated_keys.include?(entry.key))

          record = entry.site_text
          if regexp.match?(record[:id]) || regexp.match?(record[:value])
            record
          elsif (english_value = english_entries[entry.key]&.value) && regexp.match?(english_value)
            record[:value] = english_value unless only_selected_locale
            record
          end
        end
      end
    end
  end

  def self.locale_translation_keys(theme, locale:)
    field = theme.locale_fields.find { |candidate| candidate.name == locale.to_s }
    data = field&.raw_translation_data&.fetch(locale.to_sym, {}) || {}
    list_from_hash(locale:, hash: data, theme:).map(&:key).to_set
  rescue ThemeTranslationParser::InvalidYaml
    Set.new
  end

  private_class_method :locale_translation_keys

  def self.list_from_hash(locale:, hash:, theme:, parent_keys: [])
    hash
      .map do |key, value|
        this_key_array = parent_keys + [key]
        if value.is_a?(Hash)
          list_from_hash(locale: locale, hash: value, theme: theme, parent_keys: this_key_array)
        else
          new(locale: locale, theme: theme, key: this_key_array.join("."), default: value)
        end
      end
      .flatten
  end

  def initialize(locale:, key:, default:, theme:)
    @locale = locale
    @key = key
    @default = default
    @theme = theme
  end

  def site_text
    {
      id: "js.theme_translations.#{theme.id}.#{key}",
      value: value,
      status: "up_to_date",
      old_default: nil,
      new_default: default,
      overridden: has_record?,
      can_revert: has_record?,
      interpolation_keys: I18nInterpolationKeysFinder.find(default).sort,
    }
  end

  def revert!
    theme.with_lock do
      theme.theme_translation_overrides.reload
      db_record&.destroy!
      theme.theme_translation_overrides.reset
    end
  end

  def value
    has_record? ? db_record.value : default
  end

  def value=(new_value)
    if new_value == @default
      db_record.destroy! if db_record
      new_value
    else
      if has_record?
        record = db_record
        record.value = new_value.to_s
        record.save!
      else
        record = create_record!(new_value.to_s)
      end
      record.value
    end
  ensure
    theme.theme_translation_overrides.reset
  end

  def db_record
    theme.theme_translation_overrides.to_a.find do |i|
      i.locale.to_s == @locale.to_s && i.translation_key.to_s == key.to_s
    end
  end

  def has_record?
    db_record.present?
  end

  def create_record!(value)
    ThemeTranslationOverride.create!(
      locale: @locale,
      translation_key: @key,
      theme: @theme,
      value: value,
    )
  end
end
