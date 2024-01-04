# frozen_string_literal: true

class AddIndexOnCategoriesPosition < ActiveRecord::Migration[7.0]
  def change
    add_index :categories, :position
  end
end
