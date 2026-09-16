# frozen_string_literal: true
class CreateWireframeBlockLayoutCompanions < ActiveRecord::Migration[8.0]
  def change
    create_table :wireframe_block_layout_companions do |t|
      t.integer :parent_theme_id, null: false
      t.integer :component_theme_id, null: false
      t.timestamps
    end

    # A component is the block-layout companion of exactly one parent theme.
    add_index :wireframe_block_layout_companions, :component_theme_id, unique: true
    add_index :wireframe_block_layout_companions, :parent_theme_id
  end
end
