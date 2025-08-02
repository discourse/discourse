# frozen_string_literal: true

class AddSsoProviderSecretsToSiteSettings < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      SELECT 'sso_provider_secrets', 8, '*|' || value, now(), now()
      FROM site_settings WHERE name = 'sso_secret'
      AND EXISTS (
        SELECT 1 FROM site_settings WHERE name = 'enable_sso_provider' AND value = 't'
      )
    SQL
  end

  def down
    execute "DELETE FROM site_settings WHERE name = 'sso_provider_secrets'"
  end
end
