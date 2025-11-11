# frozen_string_literal: true
#
class CreateAiPersonas < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_personas do |t|
      t.string :name, null: false, unique: true, limit: 100
      t.string :description, null: false, limit: 2000
      t.string :commands, array: true, default: [], null: false
      t.string :system_prompt, null: false, limit: 10_000_000
      t.integer :allowed_group_ids, array: true, default: [], null: false
      t.integer :created_by_id
      t.boolean :enabled, default: true, null: false
      t.timestamps
    end

    add_index :ai_personas, :name, unique: true
  end
end
