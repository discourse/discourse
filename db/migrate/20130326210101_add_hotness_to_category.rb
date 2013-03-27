class AddHotnessToCategory < ActiveRecord::Migration
  def change
    add_column :categories, :hotness, :float, default: 5.0, null: false
  end
end
