# frozen_string_literal: true

class CreateLlmModelTable < ActiveRecord::Migration[7.0]
  def change
    create_table :llm_models do |t|
      t.string :display_name
      t.string :name, null: false
      t.string :provider, null: false
      t.string :tokenizer, null: false
      t.integer :max_prompt_tokens, null: false
      t.timestamps
    end
  end
end
