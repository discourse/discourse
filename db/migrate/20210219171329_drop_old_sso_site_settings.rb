# frozen_string_literal: true

class DropOldSsoSiteSettings < ActiveRecord::Migration[6.0]
  def up
    # These were copied to their new names in migrate/20210204135429_rename_sso_site_settings
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name IN (
        'enable_sso',
        'sso_allows_all_return_paths',
        'enable_sso_provider',
        'verbose_sso_logging',
        'sso_url',
        'sso_secret',
        'sso_provider_secrets',
        'sso_overrides_groups',
        'sso_overrides_bio',
        'sso_overrides_email',
        'sso_overrides_username',
        'sso_overrides_name',
        'sso_overrides_avatar',
        'sso_overrides_profile_background',
        'sso_overrides_location',
        'sso_overrides_website',
        'sso_overrides_card_background',
        'external_auth_skip_create_confirm',
        'external_auth_immediately'
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
