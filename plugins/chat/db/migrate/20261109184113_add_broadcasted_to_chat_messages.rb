# frozen_string_literal: true

class AddBroadcastedToChatMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_messages, :broadcasted, :boolean, default: false, null: false
  end
end
