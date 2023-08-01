# frozen_string_literal: true

class AddSidebarSectionIdToSidebarSectionLinks < ActiveRecord::Migration[7.0]
  def change
    add_column :sidebar_section_links, :sidebar_section_id, :integer, index: true
  end
end
