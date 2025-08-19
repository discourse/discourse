# frozen_string_literal: true

class CreateAiTools < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_tools do |t|
      t.string :name, null: false, max_length: 100, unique: true
      t.string :description, null: false, max_length: 1000

      t.string :summary, null: false, max_length: 255

      t.jsonb :parameters, null: false, default: {}
      t.text :script, null: false, max_length: 100_000
      t.integer :created_by_id, null: false

      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
  end
end
