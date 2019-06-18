# frozen_string_literal: true

class AddUserCustomFields < ActiveRecord::Migration[4.2]
  def change
    create_table :user_custom_fields do |t|
      t.integer :user_id, null: false
      t.string :name, limit: 256, null: false
      t.text :value
      t.timestamps null: false
    end

    add_index :user_custom_fields, [:user_id, :name]
  end
end
