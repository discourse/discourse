# frozen_string_literal: true

class CreateChatMessageSearchData < ActiveRecord::Migration[7.1]
  def change
    create_table :chat_message_search_data, id: false do |t|
      t.bigint :chat_message_id, null: false, primary_key: true
      t.tsvector :search_data
      t.text :raw_data
      t.text :locale
      t.integer :version, default: 0
    end

    add_index :chat_message_search_data, :search_data, using: :gin, name: "idx_search_chat_message"
  end
end
