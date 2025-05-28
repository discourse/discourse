# frozen_string_literal: true

class CopyTranslationTargetLanguagesToContentLocalizationSupportedLocales < ActiveRecord::Migration[
  7.2
]
  def up
    translation_settings =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'automatic_translation_target_languages'",
      )

    if translation_settings.present?
      DB.exec(
        "UPDATE site_settings SET value = :value WHERE name = 'experimental_content_localization_supported_locales'",
        value: translation_settings[0],
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
