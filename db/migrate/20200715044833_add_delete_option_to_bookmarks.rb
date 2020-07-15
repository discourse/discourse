# frozen_string_literal: true

class AddDeleteOptionToBookmarks < ActiveRecord::Migration[6.0]
  def change
    add_column :bookmarks, :delete_option, :integer, index: true, null: true
    DB.exec("UPDATE bookmarks SET delete_option = 1 WHERE delete_when_reminder_sent")
  end
end
