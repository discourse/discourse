# frozen_string_literal: true

class AddSearchPriorityToCategories < ActiveRecord::Migration[5.2]
  def change
    add_column :categories, :search_priority, :integer, default: 0
    add_index :categories, :search_priority
  end
end
