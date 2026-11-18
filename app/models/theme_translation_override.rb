# frozen_string_literal: true

class ThemeTranslationOverride < ActiveRecord::Base
  belongs_to :theme

  validate :check_interpolation_keys

  before_validation :capture_original_translation,
                    if: -> { new_record? || will_save_change_to_value? }

  after_commit do
    theme.theme_fields.where(target_id: Theme.targets[:translations]).update_all(value_baked: nil)
    theme.remove_from_cache!
  end

  def default_locale
    source_definition.first
  end

  def source_text
    source_definition.last
  end

  def current_default
    source_text
  end

  def status
    return "invalid_interpolation_keys" if invalid_interpolation_keys.present?

    return "deprecated" if current_default.nil?
    return "unknown" if original_translation.nil?

    if original_translation == current_default
      "up_to_date"
    else
      "outdated"
    end
  end

  def interpolation_keys
    # Locale-file code can supply arguments absent from its shipped text.
    object_default = theme.object_translation_defaults(strict: false)[translation_key]
    return unless object_default

    keys = I18nInterpolationKeysFinder.find(object_default[:text])
    if translation_key.match?(/\.(zero|one|two|few|many)\z/)
      other =
        self.class.new(theme:, locale:, translation_key: translation_key.sub(/\.[^.]+\z/, ".other"))
      keys |= other.interpolation_keys || []
    end
    keys.sort
  end

  def invalid_interpolation_keys
    keys = interpolation_keys
    return [] if keys.nil? || !value.is_a?(String)
    value.scan(/%\{([^{}]+?)\}/).flatten.uniq - keys
  end

  def make_up_to_date!
    return false if %w[outdated unknown].exclude?(status)
    update!(original_translation: current_default)
  end

  private

  def source_definition
    if object_default = theme.object_translation_defaults(strict: false)[translation_key]
      return object_default[:locale], translation_key, object_default[:text]
    end

    keys = [translation_key, TranslationOverride.transform_pluralized_key(translation_key)].uniq
    (["en"] + I18n.fallbacks[locale].map(&:to_s)).uniq.each do |source_locale|
      data = theme.default_translation_data(source_locale)
      keys.each do |key|
        text =
          key.split(".").reduce(data) { |value, part| value.is_a?(Hash) ? value[part.to_sym] : nil }
        return source_locale, key, text if text.is_a?(String)
      end
    rescue ThemeTranslationParser::InvalidYaml
      next
    end
    [locale, translation_key, nil]
  end

  def check_interpolation_keys
    keys = invalid_interpolation_keys
    return if keys.empty?

    errors.add(
      :base,
      I18n.t(
        "activerecord.errors.models.translation_overrides.attributes.value.invalid_interpolation_keys",
        keys: keys.join(I18n.t("word_connector.comma")),
        count: keys.size,
      ),
    )
  end

  def capture_original_translation
    self.original_translation = current_default
  end
end

# == Schema Information
#
# Table name: theme_translation_overrides
#
#  id                   :bigint           not null, primary key
#  locale               :string           not null
#  original_translation :text
#  translation_key      :string           not null
#  value                :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  theme_id             :integer          not null
#
# Indexes
#
#  index_theme_translation_overrides_on_theme_id  (theme_id)
#  theme_translation_overrides_unique             (theme_id,locale,translation_key) UNIQUE
#
