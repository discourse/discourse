# frozen_string_literal: true

class FixCategoriesConstraint < ActiveRecord::Migration[4.2]
  def change
    remove_index :categories, name: 'index_categories_on_parent_category_id_and_name'

    # Remove any previous duplicates
    execute "DELETE FROM categories WHERE id IN (SELECT id FROM (SELECT id, row_number() over (partition BY parent_category_id, name ORDER BY id) AS rnum FROM categories) t WHERE t.rnum > 1)"

    # Create a proper index for two categories not to have the same parent
    execute "CREATE UNIQUE INDEX unique_index_categories_on_name ON categories (COALESCE(parent_category_id, -1), name)"
  end
end
