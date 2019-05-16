# frozen_string_literal: true

class AddPostActionIdToNotifications < ActiveRecord::Migration[4.2]
  def change
    add_column :notifications, :post_action_id, :integer, null: true
    add_index :notifications, :post_action_id
  end
end
