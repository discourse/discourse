class MakePositionNullableInCategories < ActiveRecord::Migration
  def up
    change_column :categories, :position, :integer, null: true
  end

  def down
    execute "update categories set position=0 where position is null"
    change_column :categories, :position, :integer, null: false
  end
end
