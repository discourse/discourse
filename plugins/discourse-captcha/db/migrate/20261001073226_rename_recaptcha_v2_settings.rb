# frozen_string_literal: true

class RenameRecaptchaV2Settings < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET value = 'recaptcha_v2'
      WHERE name = 'discourse_captcha_provider' AND value = 'recaptcha'
    SQL

    execute <<~SQL
      UPDATE site_settings
      SET name = 'recaptcha_v2_site_key'
      WHERE name = 'recaptcha_site_key'
    SQL

    execute <<~SQL
      UPDATE site_settings
      SET name = 'recaptcha_v2_secret_key'
      WHERE name = 'recaptcha_secret_key'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
