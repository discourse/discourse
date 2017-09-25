class RenameAutoCloseDaysToHours < ActiveRecord::Migration[4.2]
  def up
    rename_column :categories, :auto_close_days, :auto_close_hours
    execute "update categories set auto_close_hours = auto_close_hours * 24"
  end

  def down
    rename_column :categories, :auto_close_hours, :auto_close_days
    execute "update categories set auto_close_days = auto_close_days / 24"
  end
end
