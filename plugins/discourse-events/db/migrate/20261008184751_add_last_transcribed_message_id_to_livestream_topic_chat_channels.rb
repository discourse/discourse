# frozen_string_literal: true

class AddLastTranscribedMessageIdToLivestreamTopicChatChannels < ActiveRecord::Migration[8.0]
  def change
    add_column :livestream_topic_chat_channels, :last_transcribed_message_id, :bigint
  end
end
