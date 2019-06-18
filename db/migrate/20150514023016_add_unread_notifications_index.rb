# frozen_string_literal: true

class AddUnreadNotificationsIndex < ActiveRecord::Migration[4.2]
  def change
    add_index :notifications, [:user_id, :notification_type], where: 'not read', name: 'idx_notifications_speedup_unread_count'
  end
end
