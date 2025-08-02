# frozen_string_literal: true

class AddPositionToSidebarSectionLinks < ActiveRecord::Migration[7.0]
  def change
    add_column :sidebar_section_links, :position, :integer, default: 0, null: false
    execute "UPDATE sidebar_section_links SET position = id"
    add_index :sidebar_section_links,
              %i[user_id sidebar_section_id position],
              unique: true,
              name: "links_user_id_section_id_position"
  end
end
