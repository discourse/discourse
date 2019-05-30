# frozen_string_literal: true

class IncreaseDataLengthOnNotifications < ActiveRecord::Migration[4.2]
  def up
    execute "ALTER TABLE notifications ALTER COLUMN data TYPE VARCHAR(1000)"
  end

  def down
    # Don't need to revert it to the smaller size
  end
end
