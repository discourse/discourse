# frozen_string_literal: true

class AddSystemToSidebarSections < ActiveRecord::Migration[7.0]
  def change
    add_column :sidebar_sections, :system, :boolean, default: false, null: false
  end
end
