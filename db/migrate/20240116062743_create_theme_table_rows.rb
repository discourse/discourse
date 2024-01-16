# frozen_string_literal: true

class CreateThemeTableRows < ActiveRecord::Migration[7.0]
  def change
    create_table :theme_table_rows do |t|
      t.bigint :theme_table_id, null: false
      t.jsonb :data, null: false

      t.timestamps
    end

    add_index :theme_table_rows, :theme_table_id
    add_index :theme_table_rows, :data, using: :gin
  end
end
