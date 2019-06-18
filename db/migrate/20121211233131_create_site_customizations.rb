# frozen_string_literal: true

class CreateSiteCustomizations < ActiveRecord::Migration[4.2]
  def change
    create_table :site_customizations do |t|
      t.string :name, null: false
      t.text :stylesheet
      t.text :header
      t.integer :position, null: false
      t.integer :user_id, null: false
      t.boolean :enabled, null: false
      t.string :key, null: false
      t.timestamps null: false
    end

    add_index :site_customizations, [:key]
  end
end
