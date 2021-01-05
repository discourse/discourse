# frozen_string_literal: true

class AddProcessedToNotifications < ActiveRecord::Migration[6.0]
  def up
    add_column :notifications, :processed, :boolean, default: false
    execute "UPDATE notifications SET processed = true"
    change_column_null(:notifications, :processed, false)
    # CREATE INDEX!
  end

  def down
    remove_column :notifications, :processed
  end
end
