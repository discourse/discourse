# frozen_string_literal: true

class AddLinkableIndexToSidebarSectionLinks < ActiveRecord::Migration[7.0]
  def change
    add_index :sidebar_section_links, %i[linkable_type linkable_id]
  end
end
