# frozen_string_literal: true

class DropReminderTypeIndexForBookmarks < ActiveRecord::Migration[6.1]
  def up
    if index_exists?(:bookmarks, [:reminder_type])
      remove_index :bookmarks, [:reminder_type]
    end
  end

  def down
    if !index_exists?(:bookmarks, [:reminder_type])
      add_index :bookmarks, :reminder_type
    end
  end
end
