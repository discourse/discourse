# frozen_string_literal: true

class AddSortFieldsToCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :sort_order, :string
    add_column :categories, :sort_ascending, :boolean
  end
end
