class IncreaseDataLengthOnNotifications < ActiveRecord::Migration
  def up
    execute "ALTER TABLE notifications ALTER COLUMN data TYPE VARCHAR(1000)"
  end

  def down
    # Don't need to revert it to the smaller size
  end
end
