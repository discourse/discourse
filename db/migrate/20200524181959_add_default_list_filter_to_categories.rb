# frozen_string_literal: true

class AddDefaultListFilterToCategories < ActiveRecord::Migration[6.0]
  def change
    add_column :categories, :default_list_filter, :string, limit: 20, default: 'all'
  end
end
