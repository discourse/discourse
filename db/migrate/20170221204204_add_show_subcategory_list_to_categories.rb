# frozen_string_literal: true

class AddShowSubcategoryListToCategories < ActiveRecord::Migration[4.2]
  def up
    add_column :categories, :show_subcategory_list, :boolean, default: false

    result = execute("select count(1) from site_settings where name = 'show_subcategory_list' and value = 't'")
    if result[0] && result[0]["count"].to_i > (0)
      execute "UPDATE categories SET show_subcategory_list = true WHERE parent_category_id IS NULL"
    end
  end

  def down
    remove_column :categories, :show_subcategory_list
  end
end
