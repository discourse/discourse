# frozen_string_literal: true
class CreateChatReactions < ActiveRecord::Migration[6.1]
  def change
    create_table :chat_message_reactions do |t|
      t.integer :chat_message_id
      t.integer :user_id
      t.string :emoji
      t.timestamps
    end

    add_index :chat_message_reactions,
              %i[chat_message_id user_id emoji],
              unique: true,
              name: :chat_message_reactions_index
  end
end
