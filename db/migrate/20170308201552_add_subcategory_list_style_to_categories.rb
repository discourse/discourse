# frozen_string_literal: true

class AddSubcategoryListStyleToCategories < ActiveRecord::Migration[4.2]
  def up
    add_column :categories, :subcategory_list_style, :string, limit: 50, default: 'rows_with_featured_topics'

    result = execute("select value from site_settings where name = 'desktop_category_page_style' and value != 'categories_with_featured_topics'")
    if result.count > 0
      execute "UPDATE categories SET subcategory_list_style = 'rows' WHERE parent_category_id IS NULL"
    end
  end

  def down
    remove_column :categories, :subcategory_list_style
  end
end
