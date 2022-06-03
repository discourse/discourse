# frozen_string_literal: true

class DisallowNullEmojiOnUserStatus < ActiveRecord::Migration[7.0]
  def up
    execute "UPDATE user_statuses SET emoji = 'mega'"
    change_column :user_statuses, :emoji, :string, null: false
  end

  def down
    change_column :user_statuses, :emoji, :string, null: true
  end
end
