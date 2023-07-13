# frozen_string_literal: true

class DropReminderTypeIndexForBookmarks < ActiveRecord::Migration[6.1]
  def up
    remove_index :bookmarks, [:reminder_type] if index_exists?(:bookmarks, [:reminder_type])
  end

  def down
    add_index :bookmarks, :reminder_type if !index_exists?(:bookmarks, [:reminder_type])
  end
end
