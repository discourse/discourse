class AddNotNullMinimumRequiredTagsOnCategories < ActiveRecord::Migration[5.2]
  def change
    change_column_null :categories, :minimum_required_tags, false, 0
  end
end
