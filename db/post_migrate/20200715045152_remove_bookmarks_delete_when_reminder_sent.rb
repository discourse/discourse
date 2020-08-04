# frozen_string_literal: true

class RemoveBookmarksDeleteWhenReminderSent < ActiveRecord::Migration[6.0]
  def up
    remove_column :bookmarks, :delete_when_reminder_sent
  end

  def down
    add_column :bookmarks, :delete_when_reminder_sent, :boolean, default: false
  end
end
