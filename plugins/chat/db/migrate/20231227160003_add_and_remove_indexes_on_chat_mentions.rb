# frozen_string_literal: true

class AddAndRemoveIndexesOnChatMentions < ActiveRecord::Migration[7.0]
  def up
    remove_index :chat_mentions, name: :chat_mentions_index
    add_index :chat_mentions, %i[chat_message_id]
    add_index :chat_mentions, %i[target_id]
  end

  def down
    remove_index :chat_mentions, %i[target_id]
    remove_index :chat_mentions, %i[chat_message_id]
    add_index :chat_mentions,
              %i[chat_message_id user_id notification_id],
              unique: true,
              name: "chat_mentions_index"
  end
end
