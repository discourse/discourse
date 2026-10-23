# frozen_string_literal: true

class PreserveOidcEmailVerifiedClaimFallback < ActiveRecord::Migration[8.1]
  def up
    return if !Migration::Helpers.existing_site?

    execute <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      SELECT 'openid_connect_email_verified_claim_fallback', 5, 't', NOW(), NOW()
      WHERE EXISTS (
        SELECT 1 FROM site_settings WHERE name = 'openid_connect_enabled' AND value = 't'
      )
      ON CONFLICT (name) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
