# frozen_string_literal: true

class AddIndexToLivestreamTopicChatChannelsOnChatChannelId < ActiveRecord::Migration[8.0]
  def change
    add_index :livestream_topic_chat_channels, :chat_channel_id
  end
end
