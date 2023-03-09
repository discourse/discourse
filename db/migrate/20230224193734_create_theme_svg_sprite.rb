# frozen_string_literal: true

class CreateThemeSvgSprite < ActiveRecord::Migration[7.0]
  def change
    create_table :theme_svg_sprites do |t|
      t.integer :theme_id, null: false
      t.integer :upload_id, null: false
      t.string :sprite, null: false, limit: 4 * 1024**2

      t.timestamps
    end

    add_index :theme_svg_sprites, :theme_id, unique: true
  end
end
