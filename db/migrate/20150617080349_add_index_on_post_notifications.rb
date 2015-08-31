class AddIndexOnPostNotifications < ActiveRecord::Migration
  def change
    add_index :notifications, [:user_id, :topic_id, :post_number]
  end
end
