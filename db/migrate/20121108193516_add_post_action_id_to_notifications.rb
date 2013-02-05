class AddPostActionIdToNotifications < ActiveRecord::Migration
  def change
    add_column :notifications, :post_action_id, :integer, null: true
    add_index :notifications, :post_action_id
  end
end
