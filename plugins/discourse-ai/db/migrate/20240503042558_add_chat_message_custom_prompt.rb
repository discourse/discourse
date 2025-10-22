# frozen_string_literal: true
class AddChatMessageCustomPrompt < ActiveRecord::Migration[7.0]
  def change
    create_table :chat_message_custom_prompts do |t|
      t.bigint :message_id, null: false
      t.json :custom_prompt, null: false
      t.timestamps
    end

    add_index :chat_message_custom_prompts, :message_id, unique: true
  end
end
