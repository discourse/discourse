# frozen_string_literal: true

class AddUniqueIndexCategoriesOnSlug < ActiveRecord::Migration[6.0]
  def change
    add_index(
      :categories,
      'COALESCE(parent_category_id, -1), slug',
      name: 'unique_index_categories_on_slug'
    )
  end
end
