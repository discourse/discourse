# frozen_string_literal: true

class CreateChatUploads < ActiveRecord::Migration[6.1]
  def change
    create_table :chat_uploads do |t|
      t.integer :chat_message_id, null: false
      t.integer :upload_id, null: false
      t.timestamps
    end

    add_index :chat_uploads, %i[chat_message_id upload_id], unique: true
  end
end
