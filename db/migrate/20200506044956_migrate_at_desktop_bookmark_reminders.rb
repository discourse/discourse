# frozen_string_literal: true

class MigrateAtDesktopBookmarkReminders < ActiveRecord::Migration[6.0]
  def up
    # reminder_type 0 is at_desktop, which is no longer valid
    DB.exec(<<~SQL, now: Time.zone.now)
        UPDATE bookmarks SET reminder_type = NULL, reminder_at = NULL, updated_at = :now
        WHERE reminder_type = 0
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
