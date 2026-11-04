# frozen_string_literal: true

class CreateChatDiscoverableBots < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_discoverable_bots do |t|
      t.integer :user_id, null: false
      t.timestamps
    end
    add_index :chat_discoverable_bots, :user_id, unique: true
  end
end
