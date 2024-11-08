# frozen_string_literal: true

class RenameSsoSiteSettings < ActiveRecord::Migration[6.0]
  RENAME_SETTINGS = [
    %w[enable_sso enable_discourse_connect],
    %w[sso_allows_all_return_paths discourse_connect_allows_all_return_paths],
    %w[enable_sso_provider enable_discourse_connect_provider],
    %w[verbose_sso_logging verbose_discourse_connect_logging],
    %w[sso_url discourse_connect_url],
    %w[sso_secret discourse_connect_secret],
    %w[sso_provider_secrets discourse_connect_provider_secrets],
    %w[sso_overrides_groups discourse_connect_overrides_groups],
    %w[sso_overrides_bio discourse_connect_overrides_bio],
    %w[sso_overrides_email auth_overrides_email],
    %w[sso_overrides_username auth_overrides_username],
    %w[sso_overrides_name auth_overrides_name],
    %w[sso_overrides_avatar discourse_connect_overrides_avatar],
    %w[sso_overrides_profile_background discourse_connect_overrides_profile_background],
    %w[sso_overrides_location discourse_connect_overrides_location],
    %w[sso_overrides_website discourse_connect_overrides_website],
    %w[sso_overrides_card_background discourse_connect_overrides_card_background],
    %w[external_auth_skip_create_confirm auth_skip_create_confirm],
    %w[external_auth_immediately auth_immediately],
  ].freeze

  def up
    # Copying the rows so that things keep working during deploy
    # They will be dropped in post_migrate/20210219171329_drop_old_sso_site_settings

    RENAME_SETTINGS.each { |old_name, new_name| execute <<~SQL }
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        SELECT '#{new_name}', data_type, value, created_at, updated_at
        FROM site_settings
        WHERE name = '#{old_name}'
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
