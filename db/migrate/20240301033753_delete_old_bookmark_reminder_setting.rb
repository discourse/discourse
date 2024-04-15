# frozen_string_literal: true

class DeleteOldBookmarkReminderSetting < ActiveRecord::Migration[7.0]
  def up
    DB.exec("DELETE FROM site_settings WHERE name = 'enable_bookmarks_with_reminders'")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
