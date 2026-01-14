# frozen_string_literal: true
#
class AddUserIdMentionableDefaultLlmToAiPersonas < ActiveRecord::Migration[7.0]
  def change
    change_table :ai_personas do |t|
      t.integer :user_id, null: true
      t.boolean :mentionable, default: false, null: false
      t.text :default_llm, null: true, length: 250
    end
  end
end
