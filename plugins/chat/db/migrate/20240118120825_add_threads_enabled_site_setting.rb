# frozen_string_literal: true

class AddThreadsEnabledSiteSetting < ActiveRecord::Migration[7.0]
  def up
    threading_enabled_channels =
      DB.query_single(
        "SELECT threading_enabled FROM chat_channels WHERE threading_enabled = 't' LIMIT 1",
      )
    return unless threading_enabled_channels.present?

    threads_enabled =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'chat_threads_enabled'").first

    if threads_enabled.nil?
      enable_threads = threading_enabled_channels.present? ? "t" : "f"
      DB.exec(
        "INSERT INTO site_settings(name, value, data_type, created_at, updated_at) VALUES('chat_threads_enabled', '#{enable_threads}', 1, NOW(), NOW())",
      )
    elsif threads_enabled == "f"
      DB.exec("UPDATE site_settings SET value = 't' WHERE name = 'chat_threads_enabled'")
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
