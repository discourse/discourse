class AddDefaultTopPeriodToCategories < ActiveRecord::Migration
  def change
    add_column :categories, :default_top_period, :string, limit: 20, default: 'all'
  end
end
