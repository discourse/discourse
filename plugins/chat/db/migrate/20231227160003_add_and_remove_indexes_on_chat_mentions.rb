# frozen_string_literal: true

class AddAndRemoveIndexesOnChatMentions < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!
  def up
    remove_index :chat_mentions,
                 name: :chat_mentions_index,
                 algorithm: :concurrently,
                 if_exists: true
    add_index :chat_mentions, %i[chat_message_id], algorithm: :concurrently
    add_index :chat_mentions, %i[target_id], algorithm: :concurrently
  end

  def down
    remove_index :chat_mentions, %i[target_id], algorithm: :concurrently, if_exists: true
    remove_index :chat_mentions, %i[chat_message_id], algorithm: :concurrently, if_exists: true
    add_index :chat_mentions,
              %i[chat_message_id user_id notification_id],
              unique: true,
              name: "chat_mentions_index",
              algorithm: :concurrently
  end
end
