# frozen_string_literal: true

class NotNullNotificationLevelInCategoryUsers < ActiveRecord::Migration[6.1]
  def change
    up_only { execute("DELETE FROM category_users WHERE notification_level IS NULL") }
    change_column_null :category_users, :notification_level, false
  end
end
