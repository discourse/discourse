# frozen_string_literal: true

class AddShowNotificationToastsToUserOptions < ActiveRecord::Migration[8.0]
  def change
    add_column :user_options, :show_notification_toasts, :boolean, default: false, null: false
  end
end
