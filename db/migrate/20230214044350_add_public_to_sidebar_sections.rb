# frozen_string_literal: true

class AddPublicToSidebarSections < ActiveRecord::Migration[7.0]
  def change
    add_column :sidebar_sections, :public, :boolean, null: false, default: false
  end
end
