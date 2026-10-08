# frozen_string_literal: true

module DiscourseEvents
  module Livestream
    class TopicChatChannel < ActiveRecord::Base
      self.table_name = "livestream_topic_chat_channels"
      belongs_to :topic
      belongs_to :chat_channel, class_name: "Chat::Channel", dependent: :destroy

      def untranscribed_messages
        chat_channel
          .chat_messages
          .where.not(id: reference_message_id)
          .where("chat_messages.id > ?", last_transcribed_message_id.to_i)
          .includes(:user, :chat_channel)
      end
    end
  end
end

# == Schema Information
#
# Table name: livestream_topic_chat_channels
#
#  id                          :bigint           not null, primary key
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  chat_channel_id             :bigint           not null
#  last_transcribed_message_id :bigint
#  reference_message_id        :bigint
#  topic_id                    :bigint           not null
#
# Indexes
#
#  index_livestream_topic_chat_channels_on_chat_channel_id  (chat_channel_id)
#  unique_livestream_topic_chat_channels                    (topic_id,chat_channel_id) UNIQUE
#
