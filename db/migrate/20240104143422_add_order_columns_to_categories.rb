# frozen_string_literal: true

class AddOrderColumnsToCategories < ActiveRecord::Migration[7.0]
  def change
    add_column :categories, :position_to_parent, :integer, default: 0
    add_column :categories, :depth, :integer, default: 0
    add_column :categories, :path, :integer, array: true

    add_index :categories, :position
    add_index :categories, :position_to_parent
    add_index :categories, :path
  end
end
