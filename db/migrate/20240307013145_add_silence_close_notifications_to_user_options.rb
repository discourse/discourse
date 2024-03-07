# frozen_string_literal: true

class AddSilenceCloseNotificationsToUserOptions < ActiveRecord::Migration[7.0]
  def change
    add_column :user_options, :silence_close_notifications, :boolean, default: false, null: false
  end
end
