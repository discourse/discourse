# frozen_string_literal: true

class AddLastReminderAtToBookmarks < ActiveRecord::Migration[6.1]
  def change
    add_column :bookmarks, :last_reminder_at, :datetime
  end
end
