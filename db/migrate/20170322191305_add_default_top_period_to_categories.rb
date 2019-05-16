# frozen_string_literal: true

class AddDefaultTopPeriodToCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :default_top_period, :string, limit: 20, default: 'all'
  end
end
