# frozen_string_literal: true

class MigrateHcaptchaEnabledToCaptchaSettings < ActiveRecord::Migration[7.2]
  def up
    hcaptcha_was_enabled =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'discourse_hcaptcha_enabled'",
      ).first

    return if hcaptcha_was_enabled != "t"

    execute <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('discourse_captcha_enabled', 5, 't', NOW(), NOW())
      ON CONFLICT (name) DO UPDATE SET value = 't', updated_at = NOW()
    SQL

    execute <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('discourse_captcha_provider', 7, 'hcaptcha', NOW(), NOW())
      ON CONFLICT (name) DO UPDATE SET value = 'hcaptcha', updated_at = NOW()
    SQL

    execute "DELETE FROM site_settings WHERE name = 'discourse_hcaptcha_enabled'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
