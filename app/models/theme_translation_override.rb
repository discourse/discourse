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

  def current_default
    object_default = theme.object_translation_defaults[translation_key]
    default_locale = object_default&.dig(:locale) || "en"
    default_key = translation_key
    if !object_default &&
         theme.default_translation_data.dig(*default_key.split(".").map(&:to_sym)).nil?
      default_key = TranslationOverride.transform_pluralized_key(default_key)
    end
    if locale != default_locale
      overrides = theme.theme_translation_overrides
      override =
        if overrides.loaded?
          overrides.find do |entry|
            entry.locale == default_locale && entry.translation_key == default_key
          end
        else
          overrides.find_by(locale: default_locale, translation_key: default_key)
        end
      return override.value if override
    end
    return object_default[:text] if object_default

    theme.default_translation_data.dig(*default_key.split(".").map(&:to_sym))
  rescue ThemeTranslationParser::InvalidYaml
    nil
  end

  def status
    return "invalid_interpolation_keys" if invalid_interpolation_keys.present?

    if original_translation == current_default && !original_translation.nil?
      "up_to_date"
    else
      "outdated"
    end
  end

  def invalid_interpolation_keys
    source = current_default
    return [] unless source.is_a?(String) && value.is_a?(String)
    value.scan(/%\{([^{}]+?)\}/).flatten.uniq - I18nInterpolationKeysFinder.find(source)
  end

  def make_up_to_date!
    return false unless status == "outdated"
    update!(original_translation: current_default)
  end

  private

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
