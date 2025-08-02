# frozen_string_literal: true

class AddReminderSetAtToBookmarks < ActiveRecord::Migration[6.0]
  def change
    add_column :bookmarks, :reminder_set_at, :datetime, null: true
    add_index :bookmarks, :reminder_set_at
  end
end
