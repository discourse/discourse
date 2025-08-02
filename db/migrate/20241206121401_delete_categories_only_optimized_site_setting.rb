# frozen_string_literal: true

class DeleteCategoriesOnlyOptimizedSiteSetting < ActiveRecord::Migration[7.2]
  def up
    execute "DELETE FROM site_settings WHERE name = 'desktop_category_page_style' AND value = 'categories_only_optimized'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
