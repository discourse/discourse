# frozen_string_literal: true

class RenameDefaultSidebarTagsSetting < ActiveRecord::Migration[7.0]
  def change
    execute "UPDATE site_settings SET name = 'default_navigation_menu_tags' WHERE name = 'default_sidebar_tags'"
  end
end
