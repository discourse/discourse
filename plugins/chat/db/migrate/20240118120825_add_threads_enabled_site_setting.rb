# frozen_string_literal: true

class AddThreadsEnabledSiteSetting < ActiveRecord::Migration[7.0]
  def up
    return if Migration::Helpers.new_site?

    execute(<<~SQL)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('chat_threads_enabled', 5, 'f', NOW(), NOW())
      ON CONFLICT (name) DO NOTHING
    SQL

    threading_enabled_channels =
      DB.query_single("SELECT name FROM chat_channels WHERE threading_enabled = 't'")

    return if threading_enabled_channels.blank?

    DB.exec("UPDATE site_settings SET value = 't' WHERE name = 'chat_threads_enabled'")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
