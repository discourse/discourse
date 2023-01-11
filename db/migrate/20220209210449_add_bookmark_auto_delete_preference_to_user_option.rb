# frozen_string_literal: true

class AddBookmarkAutoDeletePreferenceToUserOption < ActiveRecord::Migration[6.1]
  def change
    add_column :user_options, :bookmark_auto_delete_preference, :integer, default: 3, null: false
  end
end
