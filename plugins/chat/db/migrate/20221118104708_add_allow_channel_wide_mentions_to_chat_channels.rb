# frozen_string_literal: true

class AddAllowChannelWideMentionsToChatChannels < ActiveRecord::Migration[7.0]
  def change
    add_column :chat_channels, :allow_channel_wide_mentions, :boolean, null: false, default: true
  end
end
