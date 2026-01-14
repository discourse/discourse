# frozen_string_literal: true
class CreateCompletionPromptTable < ActiveRecord::Migration[7.0]
  def change
    create_table :completion_prompts do |t|
      t.string :name, null: false
      t.string :translated_name
      t.integer :prompt_type, null: false, default: 0
      t.text :value, null: false
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end

    add_index :completion_prompts, %i[name], unique: true
  end
end
