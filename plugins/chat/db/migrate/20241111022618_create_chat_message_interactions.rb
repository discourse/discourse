# frozen_string_literal: true

class CreateChatMessageInteractions < ActiveRecord::Migration[7.1]
  def change
    create_table :chat_message_interactions, id: :bigint do |t|
      t.bigint :user_id, null: false
      t.bigint :chat_message_id, null: false
      t.jsonb :action, null: false

      t.timestamps
    end

    add_index :chat_message_interactions, :user_id
    add_index :chat_message_interactions, :chat_message_id
  end
end
