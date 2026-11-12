# frozen_string_literal: true
class AddCoveringIndexOnChatMessagesThreadId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "idx_chat_messages_thread_id_id_user_id_not_deleted"

  def change
    remove_index :chat_messages, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
    add_index :chat_messages,
              %i[thread_id id],
              include: %i[user_id],
              where: "deleted_at IS NULL",
              name: INDEX_NAME,
              algorithm: :concurrently
  end
end
