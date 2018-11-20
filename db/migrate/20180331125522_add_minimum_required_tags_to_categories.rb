class AddMinimumRequiredTagsToCategories < ActiveRecord::Migration[5.1]
  def change
    add_column :categories, :minimum_required_tags, :integer, default: 0
  end
end
