# frozen_string_literal: true

class AddCategoryIdNotificationLevelIndexToCategoryUsers < ActiveRecord::Migration[7.0]
  def change
    add_index :category_users, %i[category_id notification_level]
  end
end
