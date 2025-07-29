# frozen_string_literal: true
class EnableRichEditorForAll < ActiveRecord::Migration[7.2]
  def up
    prev_value = DB.query_single("SELECT value FROM site_settings WHERE name = 'rich_editor'").first

    # The change to default: true will automatically switch the rich editor on for all users
    return if prev_value.blank?

    # Type ID 5 is bool
    DB.exec(<<~SQL)
      UPDATE site_settings SET value = 't', updated_at = NOW()
      WHERE name = 'rich_editor'
    SQL

    # -1 is system user ID, 3 is site_setting_changed action ID
    # Insert a staff action log to record the change
    DB.exec(<<~SQL)
      INSERT INTO user_histories (acting_user_id, action, created_at, updated_at, subject, previous_value, new_value, admin_only)
      VALUES (-1, 3, NOW(), NOW(), 'rich_editor', 'f', 't', true)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
