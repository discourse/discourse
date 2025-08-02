# frozen_string_literal: true

class RenameDefaultSidebarCategoriesSetting < ActiveRecord::Migration[7.0]
  def change
    execute "UPDATE site_settings SET name = 'default_navigation_menu_categories' WHERE name = 'default_sidebar_categories'"
  end
end
