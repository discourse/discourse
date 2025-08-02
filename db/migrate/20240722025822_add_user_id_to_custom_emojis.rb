# frozen_string_literal: true
class AddUserIdToCustomEmojis < ActiveRecord::Migration[7.1]
  def change
    add_column :custom_emojis, :user_id, :integer, null: false, default: -1
  end
end
