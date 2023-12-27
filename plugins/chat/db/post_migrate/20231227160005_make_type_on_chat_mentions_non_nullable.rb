# frozen_string_literal: true

class MakeTypeOnChatMentionsNonNullable < ActiveRecord::Migration[7.0]
  def up
    change_column :chat_mentions, :type, :string, null: false
  end

  def down
    change_column :chat_mentions, :type, :string, null: true
  end
end
