# frozen_string_literal: true

class RenameEditNotificationSetting < ActiveRecord::Migration[5.2]
  def change
    execute "UPDATE site_settings SET name = 'disable_system_edit_notifications' WHERE name = 'disable_edit_notifications'"
  end
end
