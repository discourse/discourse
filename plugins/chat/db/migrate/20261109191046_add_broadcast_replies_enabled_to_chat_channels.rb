# frozen_string_literal: true

class AddBroadcastRepliesEnabledToChatChannels < ActiveRecord::Migration[8.0]
  def change
    add_column :chat_channels, :broadcast_replies_enabled, :boolean, default: false, null: false
  end
end
