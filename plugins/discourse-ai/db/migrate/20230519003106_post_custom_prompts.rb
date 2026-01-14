# frozen_string_literal: true

class PostCustomPrompts < ActiveRecord::Migration[7.0]
  def change
    create_table :post_custom_prompts do |t|
      t.integer :post_id, null: false
      t.json :custom_prompt, null: false
      t.timestamps
    end

    add_index :post_custom_prompts, :post_id, unique: true
  end
end
