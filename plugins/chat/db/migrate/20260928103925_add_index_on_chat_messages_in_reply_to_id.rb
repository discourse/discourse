# frozen_string_literal: true

class AddIndexOnChatMessagesInReplyToId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :chat_messages, :in_reply_to_id, algorithm: :concurrently, if_exists: true
    add_index :chat_messages,
              :in_reply_to_id,
              where: "in_reply_to_id IS NOT NULL",
              algorithm: :concurrently
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
