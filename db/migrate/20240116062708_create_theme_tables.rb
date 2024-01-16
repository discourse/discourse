# frozen_string_literal: true

class CreateThemeTables < ActiveRecord::Migration[7.0]
  def change
    create_table :theme_tables do |t|
      t.integer :theme_id, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :theme_tables, :theme_id
    add_index :theme_tables, %i[theme_id name], unique: true
  end
end
