# frozen_string_literal: true

class AddIconToSidebarUrls < ActiveRecord::Migration[7.0]
  def change
    add_column :sidebar_urls, :icon, :string
  end
end
