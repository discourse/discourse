# frozen_string_literal: true

class AddIndexOnPostNotifications < ActiveRecord::Migration[4.2]
  def change
    add_index :notifications, [:user_id, :topic_id, :post_number]
  end
end
