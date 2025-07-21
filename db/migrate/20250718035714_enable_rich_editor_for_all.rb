# frozen_string_literal: true
class EnableRichEditorForAll < ActiveRecord::Migration[7.2]
  def up
    # Type ID 5 is bool
    DB.exec(<<~SQL)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('rich_editor', 5, 't', NOW(), NOW())
      ON CONFLICT (name) DO UPDATE
        SET value = 't', updated_at = NOW()
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
