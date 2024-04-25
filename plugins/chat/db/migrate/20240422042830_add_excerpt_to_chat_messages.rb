# frozen_string_literal: true

class AddExcerptToChatMessages < ActiveRecord::Migration[7.0]
  def change
    add_column :chat_messages, :excerpt, :string, limit: 1000, null: true
  end
end
