# frozen_string_literal: true

class AddTypeAndTargetIdToChatMentions < ActiveRecord::Migration[7.0]
  def up
    add_column :chat_mentions, :type, :string, null: true
    add_column :chat_mentions, :target_id, :integer, null: true
    change_column :chat_mentions, :user_id, :integer, null: true

    remove_index :chat_mentions, name: :chat_mentions_index
    add_index :chat_mentions, %i[chat_message_id]
  end

  def down
    remove_index :chat_mentions, %i[chat_message_id]
    add_index :chat_mentions,
              %i[chat_message_id user_id notification_id],
              unique: true,
              name: "chat_mentions_index"

    change_column :chat_mentions, :user_id, :integer, null: false
    remove_column :chat_mentions, :target_id
    remove_column :chat_mentions, :type
  end
end
