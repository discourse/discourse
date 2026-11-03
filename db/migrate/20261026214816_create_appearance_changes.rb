# frozen_string_literal: true

class CreateAppearanceChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :appearance_changes do |t|
      t.integer :kind, null: false
      t.string :name, null: false
      t.integer :theme_id, null: false
      t.integer :light_color_scheme_id, null: false
      t.integer :dark_color_scheme_id, null: false
      t.jsonb :site_settings, null: false, default: {}
      t.jsonb :previous_state, null: false, default: {}
      t.integer :user_id, null: false
      t.datetime :activated_at
      t.timestamps
    end

    add_index :appearance_changes, :theme_id
  end
end
