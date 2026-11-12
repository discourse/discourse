# frozen_string_literal: true
class AddReferenceMessageIdToLivestreamTopicChatChannels < ActiveRecord::Migration[8.0]
  def change
    add_column :livestream_topic_chat_channels, :reference_message_id, :bigint
  end
end
