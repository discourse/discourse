# frozen_string_literal: true

class CreateThemeColorScheme < ActiveRecord::Migration[7.2]
  def change
    create_table :theme_color_schemes do |t|
      t.integer :theme_id, null: false
      t.integer :color_scheme_id, null: false
      t.timestamps null: false
    end

    add_index :theme_color_schemes, :theme_id, unique: true
    add_index :theme_color_schemes, :color_scheme_id, unique: true
  end
end
