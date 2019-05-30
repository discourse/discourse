# frozen_string_literal: true

class AddSsoProviderSecretsToSiteSettings < ActiveRecord::Migration[5.2]
  def up
    return unless SiteSetting.enable_sso_provider && SiteSetting.sso_secret.present?
    sso_secret = SiteSetting.sso_secret
    sso_secret_insert = ActiveRecord::Base.connection.quote("*|#{sso_secret}")

    execute "INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
             VALUES ('sso_provider_secrets', 8, #{sso_secret_insert}, now(), now())"
  end

  def down
    execute "DELETE FROM site_settings WHERE name = 'sso_provider_secrets'"
  end
end
