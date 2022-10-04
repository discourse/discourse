# frozen_string_literal: true

class AddCategoriesIndexes < ActiveRecord::Migration[4.2]
  def change
    add_index :categories, :logo_url
    add_index :categories, :background_url
  end
end
