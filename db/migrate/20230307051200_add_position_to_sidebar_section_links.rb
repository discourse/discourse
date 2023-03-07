# frozen_string_literal: true

class AddPositionToSidebarSectionLinks < ActiveRecord::Migration[7.0]
  def change
    add_column :sidebar_section_links, :position, :integer, default: 0, null: false
  end
end
