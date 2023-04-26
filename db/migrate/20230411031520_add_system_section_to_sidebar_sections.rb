# frozen_string_literal: true

class AddSystemSectionToSidebarSections < ActiveRecord::Migration[7.0]
  def change
    add_column :sidebar_sections, :system_section, :string
  end
end
