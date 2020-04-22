# frozen_string_literal: true

class AddReminderLastSentAtToBookmarks < ActiveRecord::Migration[6.0]
  def change
    add_column :bookmarks, :reminder_last_sent_at, :datetime, null: true
  end
end
