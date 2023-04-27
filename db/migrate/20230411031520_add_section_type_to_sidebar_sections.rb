# frozen_string_literal: true

class AddSectionTypeToSidebarSections < ActiveRecord::Migration[7.0]
  def change
    add_column :sidebar_sections, :section_type, :string
  end
end
