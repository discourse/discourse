# frozen_string_literal: true
class AddLastMessageCreatedAtToChatChannels < ActiveRecord::Migration[6.1]
  def change
    add_column :chat_channels, :last_message_sent_at, :datetime, default: -> { "CURRENT_TIMESTAMP" }
    change_column_null :chat_channels, :last_message_sent_at, false
  end
end
