# frozen_string_literal: true

class AddIsSupportToCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :is_support, :boolean, default: false, null: false
  end
end
