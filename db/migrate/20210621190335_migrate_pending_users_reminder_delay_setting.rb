# frozen_string_literal: true

class MigratePendingUsersReminderDelaySetting < ActiveRecord::Migration[6.1]
  def up
    setting_value = DB.query_single("SELECT value FROM site_settings WHERE name = 'pending_users_reminder_delay'").first

    if setting_value.present?
      new_value = setting_value.to_i
      new_value = new_value > 0 ? new_value * 60 : new_value

      DB.exec(<<~SQL, delay: new_value)
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        VALUES ('pending_users_reminder_delay_minutes', 3, :delay, NOW(), NOW())
      SQL

      DB.exec("DELETE FROM site_settings WHERE name = 'pending_users_reminder_delay'")
    end
  end

  def down
  end
end
