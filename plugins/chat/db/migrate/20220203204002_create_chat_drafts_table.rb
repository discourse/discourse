# frozen_string_literal: true

class CreateChatDraftsTable < ActiveRecord::Migration[6.1]
  def change
    create_table :chat_drafts do |t|
      t.integer :user_id, null: false
      t.integer :chat_channel_id, null: false
      t.text :data, null: false
      t.timestamps
    end
  end
end
