# frozen_string_literal: true
class AddCreatedAtToBadgeUser < ActiveRecord::Migration[6.0]
  def up
    add_column :user_badges, :created_at, :datetime, null: true
    execute 'UPDATE user_badges SET created_at = granted_at WHERE created_at IS NULL'
    change_column :user_badges, :created_at, :datetime, null: false, default: 'current_timestamp'
  end

  def down
    remove_column :user_badges, :created_at
  end
end
