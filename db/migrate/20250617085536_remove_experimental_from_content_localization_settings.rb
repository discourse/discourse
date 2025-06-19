# frozen_string_literal: true

class RemoveExperimentalFromContentLocalizationSettings < ActiveRecord::Migration[7.2]
  def up
    execute "UPDATE site_settings SET name = 'content_localization_enabled' WHERE name = 'experimental_content_localization'"
    execute "UPDATE site_settings SET name = 'content_localization_allowed_groups' WHERE name = 'experimental_content_localization_allowed_groups'"
    execute "UPDATE site_settings SET name = 'content_localization_supported_locales' WHERE name = 'experimental_content_localization_supported_locales'"
    execute "UPDATE site_settings SET name = 'content_localization_anon_language_switcher' WHERE name = 'experimental_anon_language_switcher'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
