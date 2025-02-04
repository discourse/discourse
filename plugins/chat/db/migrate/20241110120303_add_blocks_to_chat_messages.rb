# frozen_string_literal: true

class AddBlocksToChatMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :chat_messages, :blocks, :jsonb, null: true, default: nil
  end
end
