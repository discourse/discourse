# frozen_string_literal: true
class CreateBlockLayoutDrafts < ActiveRecord::Migration[8.0]
  def change
    create_table :wireframe_block_layout_drafts do |t|
      t.integer :user_id, null: false
      t.integer :theme_id, null: false
      t.string :outlet, null: false
      t.text :data, null: false
      t.string :base_version_token
      t.timestamps
    end

    add_index :wireframe_block_layout_drafts,
              %i[user_id theme_id outlet],
              unique: true,
              name: "idx_wireframe_block_layout_drafts_unique"
    add_index :wireframe_block_layout_drafts, %i[theme_id outlet]
  end
end
