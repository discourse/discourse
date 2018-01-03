class AddHotnessToCategory < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :hotness, :float, default: 5.0, null: false
  end
end
