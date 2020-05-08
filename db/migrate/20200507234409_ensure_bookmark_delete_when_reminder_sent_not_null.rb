# frozen_string_literal: true

class EnsureBookmarkDeleteWhenReminderSentNotNull < ActiveRecord::Migration[6.0]
  def change
    DB.exec("UPDATE bookmarks SET delete_when_reminder_sent = false WHERE delete_when_reminder_sent IS NULL")
    change_column_null :bookmarks, :delete_when_reminder_sent, false
  end
end
