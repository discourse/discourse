# frozen_string_literal: true

class RenameSsoSiteSettings < ActiveRecord::Migration[6.0]
  RENAME_SETTINGS = [
    ['enable_sso', 'enable_discourse_connect'],
    ['sso_allows_all_return_paths', 'discourse_connect_allows_all_return_paths'],
    ['enable_sso_provider', 'enable_discourse_connect_provider'],
    ['verbose_sso_logging', 'verbose_discourse_connect_logging'],
    ['sso_url', 'discourse_connect_url'],
    ['sso_secret', 'discourse_connect_secret'],
    ['sso_provider_secrets', 'discourse_connect_provider_secrets'],
    ['sso_overrides_groups', 'discourse_connect_overrides_groups'],
    ['sso_overrides_bio', 'discourse_connect_overrides_bio'],
    ['sso_overrides_email', 'auth_overrides_email'],
    ['sso_overrides_username', 'auth_overrides_username'],
    ['sso_overrides_name', 'auth_overrides_name'],
    ['sso_overrides_avatar', 'discourse_connect_overrides_avatar'],
    ['sso_overrides_profile_background', 'discourse_connect_overrides_profile_background'],
    ['sso_overrides_location', 'discourse_connect_overrides_location'],
    ['sso_overrides_website', 'discourse_connect_overrides_website'],
    ['sso_overrides_card_background', 'discourse_connect_overrides_card_background'],
    ['external_auth_skip_create_confirm', 'auth_skip_create_confirm'],
    ['external_auth_immediately', 'auth_immediately']
  ]

  def up
    # Copying the rows so that things keep working during deploy
    # They will be dropped in post_migrate/20210219171329_drop_old_sso_site_settings

    RENAME_SETTINGS.each do |old_name, new_name|
      execute <<~SQL
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        SELECT '#{new_name}', data_type, value, created_at, updated_at
        FROM site_settings
        WHERE name = '#{old_name}'
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
