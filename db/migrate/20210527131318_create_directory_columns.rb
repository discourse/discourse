# frozen_string_literal: true
class CreateDirectoryColumns < ActiveRecord::Migration[6.1]
  def up
    create_table :directory_columns do |t|
      t.string :name, null: true
      t.integer :automatic_position, null: true
      t.string :icon, null: true
      t.integer :user_field_id, null: true
      t.boolean :automatic, null: false
      t.boolean :enabled, null: false
      t.integer :position, null: false
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :directory_columns, %i[enabled position user_field_id], name: "directory_column_index"
  end

  def down
    drop_table :directory_columns
  end
end
