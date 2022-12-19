# frozen_string_literal: true

class AddIndexToChatMessages < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :chat_messages, [:chat_channel_id, :id], where: "deleted_at IS NULL", algorithm: :concurrently
  end
end
