# frozen_string_literal: true
class CreateChatMessagePostConnections < ActiveRecord::Migration[6.1]
  def change
    create_table :chat_message_post_connections do |t|
      t.integer :post_id, null: false
      t.integer :chat_message_id, null: false
      t.timestamps
    end

    add_index :chat_message_post_connections,
              %i[post_id chat_message_id],
              unique: true,
              name: "chat_message_post_connections_index"
  end
end
