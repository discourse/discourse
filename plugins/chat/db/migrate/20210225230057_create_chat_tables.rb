# frozen_string_literal: true

class CreateChatTables < ActiveRecord::Migration[6.0]
  def change
    create_table :topic_chats do |t|
      t.integer :topic_id, null: false, index: true, unique: true
      t.datetime :deleted_at
      t.integer :deleted_by_id

      t.integer :featured_in_category_id
      t.integer :delete_after_seconds, default: nil
    end

    create_table :topic_chat_messages do |t|
      t.integer :topic_id, null: false
      t.integer :post_id, null: false, index: true
      t.integer :user_id, null: true
      t.timestamps
      t.datetime :deleted_at
      t.integer :deleted_by_id
      t.integer :in_reply_to_id, null: true
      t.text :message
    end

    add_index :topic_chat_messages, %i[topic_id created_at]
  end
end
