# frozen_string_literal: true

class AddLimitsToSidebarSectionsAndSidebarUrls < ActiveRecord::Migration[7.0]
  def change
    execute "UPDATE sidebar_urls SET icon = 'link' WHERE icon IS NULL"
    change_column :sidebar_sections, :title, :string, limit: 30, null: false
    change_column :sidebar_urls, :icon, :string, limit: 40, null: false
    change_column :sidebar_urls, :name, :string, limit: 80, null: false
    change_column :sidebar_urls, :value, :string, limit: 200, null: false
  end
end
