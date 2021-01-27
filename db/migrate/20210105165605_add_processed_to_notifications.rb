# frozen_string_literal: true

class AddProcessedToNotifications < ActiveRecord::Migration[6.0]
  def up
    # Commented out because this was causing issues with large databases.
    # Creating a new table instead of adding this column.
    #
    # add_column :notifications, :processed, :boolean, default: false
    # execute "UPDATE notifications SET processed = true"
    # change_column_null(:notifications, :processed, false)
    # add_index :notifications, [:processed], unique: false
  end

  def down
    # remove_column :notifications, :processed
  end
end
