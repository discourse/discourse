# frozen_string_literal: true

class CreateChatMessageRevisions < ActiveRecord::Migration[6.1]
  def change
    create_table :chat_message_revisions do |t|
      t.integer :chat_message_id
      t.text :old_message, null: false
      t.text :new_message, null: false
      t.timestamps
    end

    add_index :chat_message_revisions, [:chat_message_id]
  end
end
