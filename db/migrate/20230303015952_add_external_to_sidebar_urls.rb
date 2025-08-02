# frozen_string_literal: true

class AddExternalToSidebarUrls < ActiveRecord::Migration[7.0]
  def change
    add_column :sidebar_urls, :external, :boolean, default: false, null: false
  end
end
