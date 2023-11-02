# frozen_string_literal: true

class CreateThemeSettingsMigrations < ActiveRecord::Migration[7.0]
  def change
    create_table :theme_settings_migrations do |t|
      t.integer :theme_id, null: false
      t.integer :theme_field_id, null: false
      t.integer :version, null: false
      t.string :name, null: false, limit: 150
      t.json :diff, null: false
      t.datetime :created_at, null: false
    end

    add_index :theme_settings_migrations, %i[theme_id version], unique: true
    add_index :theme_settings_migrations, :theme_field_id, unique: true
  end
end
