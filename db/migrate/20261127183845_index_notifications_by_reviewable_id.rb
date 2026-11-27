# frozen_string_literal: true

class IndexNotificationsByReviewableId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "index_notifications_on_data_reviewable_id"

  def up
    remove_index :notifications, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
    add_index :notifications,
              "(data::jsonb ->> 'reviewable_id')",
              name: INDEX_NAME,
              where: "(data::jsonb ->> 'reviewable_id') IS NOT NULL",
              algorithm: :concurrently
  end

  def down
    remove_index :notifications, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end
end
