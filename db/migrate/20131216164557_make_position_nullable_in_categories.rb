# frozen_string_literal: true

class MakePositionNullableInCategories < ActiveRecord::Migration[4.2]
  def up
    change_column :categories, :position, :integer, null: true
  end

  def down
    execute "update categories set position=0 where position is null"
    change_column :categories, :position, :integer, null: false
  end
end
