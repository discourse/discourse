# frozen_string_literal: true

class ChangeNotificationLevel < ActiveRecord::Migration[6.0]
  def up
    change_column :category_users, :notification_level, :integer, null: true
  end

  def down
    change_column :category_users, :notification_level, :integer, null: false
  end
end
