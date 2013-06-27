class AddAutoCloseDaysToCategories < ActiveRecord::Migration
  def change
    add_column :categories, :auto_close_days, :float
  end
end
