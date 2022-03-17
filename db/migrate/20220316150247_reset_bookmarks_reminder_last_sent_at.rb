# frozen_string_literal: true

class ResetBookmarksReminderLastSentAt < ActiveRecord::Migration[6.1]
  def up
    DB.exec <<~SQL
      UPDATE bookmarks
      SET reminder_last_sent_at = NULL
      WHERE reminder_last_sent_at < reminder_at
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
