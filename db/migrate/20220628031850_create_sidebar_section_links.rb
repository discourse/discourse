# frozen_string_literal: true

class CreateSidebarSectionLinks < ActiveRecord::Migration[7.0]
  def change
    create_table :sidebar_section_links do |t|
      t.integer :user_id, null: false
      t.integer :linkable_id, null: false
      t.string :linkable_type, null: false

      t.timestamps
    end

    add_index :sidebar_section_links,
              %i[user_id linkable_type linkable_id],
              unique: true,
              name: "idx_unique_sidebar_section_links"
  end
end
