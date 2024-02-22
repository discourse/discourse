# frozen_string_literal: true

class MakeTypeOnChatMentionsNonNullable < ActiveRecord::Migration[7.0]
  def up
    change_column_null :chat_mentions, :type, false
  end

  def down
    change_column_null :chat_mentions, :type, true
  end
end
