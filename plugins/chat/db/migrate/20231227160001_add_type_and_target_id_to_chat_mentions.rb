# frozen_string_literal: true

class AddTypeAndTargetIdToChatMentions < ActiveRecord::Migration[7.0]
  def up
    add_column :chat_mentions, :type, :string, null: true
    add_column :chat_mentions, :target_id, :integer, null: true
    change_column_null :chat_mentions, :user_id, true
  end

  def down
    change_column_null :chat_mentions, :user_id, false
    remove_column :chat_mentions, :target_id
    remove_column :chat_mentions, :type
  end
end
