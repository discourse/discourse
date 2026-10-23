# frozen_string_literal: true

class AddReceivedNotificationTypesToUserStats < ActiveRecord::Migration[8.1]
  def change
    # NULL preserves the existing menu for accounts created before this change.
    add_column :user_stats, :received_notification_types, :integer, array: true
    change_column_default :user_stats, :received_notification_types, from: nil, to: []
  end
end
