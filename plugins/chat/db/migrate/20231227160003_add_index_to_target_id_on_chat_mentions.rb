# frozen_string_literal: true

class AddIndexToTargetIdOnChatMentions < ActiveRecord::Migration[7.0]
  def up
    add_index :chat_mentions, %i[target_id]
  end

  def down
    remove_index :chat_mentions, %i[target_id]
  end
end
