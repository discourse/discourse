# frozen_string_literal: true

class AddDeleteWhenReminderSentBooleanToBookmarks < ActiveRecord::Migration[6.0]
  def change
    add_column :bookmarks, :delete_when_reminder_sent, :boolean, null: false, default: false
  end
end
