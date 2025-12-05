# frozen_string_literal: true

class CreateChatMessageLinks < ActiveRecord::Migration[7.2]
  def change
    create_table :chat_message_links, if_not_exists: true do |t|
      t.bigint :chat_message_id, null: false
      t.string :url, null: false, limit: 500
      t.timestamps
    end

    add_index :chat_message_links, :chat_message_id, if_not_exists: true
    add_index :chat_message_links, :url, if_not_exists: true
    add_index :chat_message_links,
              %i[chat_message_id url],
              unique: true,
              name: "unique_chat_message_links",
              if_not_exists: true
  end
end
