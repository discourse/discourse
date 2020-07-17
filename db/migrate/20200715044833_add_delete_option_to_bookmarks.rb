# frozen_string_literal: true

class AddDeleteOptionToBookmarks < ActiveRecord::Migration[6.0]
  def up
    add_column :bookmarks, :auto_delete_preference, :integer, index: true, null: false, default: 0
    DB.exec("UPDATE bookmarks SET auto_delete_preference = 1 WHERE delete_when_reminder_sent")
  end

  def down
    remove_column :bookmarks, :auto_delete_preference
  end
end
