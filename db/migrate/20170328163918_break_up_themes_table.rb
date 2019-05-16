# frozen_string_literal: true

class BreakUpThemesTable < ActiveRecord::Migration[4.2]
  def change
    create_table :theme_fields do |t|
      t.integer :theme_id, null: false
      t.integer :target, null: false
      t.string :name, null: false
      t.text :value, null: false
      t.text :value_baked
      t.timestamps null: false
    end

    add_index :theme_fields, [:theme_id, :target, :name], unique: true

    [
      [0, "embedded_scss", "embedded_scss"],
      [0, "common_scss", "scss"],
      [1, "desktop_scss", "scss"],
      [2, "mobile_scss", "scss"],
      [0, "head_tag", "head_tag"],
      [0, "body_tag", "body_tag"],
      [1, "header", "header"],
      [2, "mobile_header", "header"],
      [1, "top", "after_header"],
      [2, "mobile_top", "after_header"],
      [1, "footer", "footer"],
      [2, "mobile_footer", "footer"],
    ].each do |target, value, name|

      execute <<SQL
      INSERT INTO theme_fields (
        theme_id,
        target,
        name,
        value,
        created_at,
        updated_at
      )
      SELECT id, #{target}, '#{name}', #{value}, created_at, updated_at
      FROM themes WHERE #{value} IS NOT NULL AND LENGTH(BTRIM(#{value})) > 0
SQL
      remove_column :themes, value
    end

    %w{ head_tag_baked
        body_tag_baked
        header_baked
        footer_baked
        mobile_footer_baked
        mobile_header_baked
       }.each do |col|
      remove_column :themes, col
    end
  end
end
