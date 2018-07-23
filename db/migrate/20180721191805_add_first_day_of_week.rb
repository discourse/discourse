class AddFirstDayOfWeek < ActiveRecord::Migration[5.2]
  def change
    add_column :user_options, :first_day_of_week, :integer, null: false, default: 1
  end
end
