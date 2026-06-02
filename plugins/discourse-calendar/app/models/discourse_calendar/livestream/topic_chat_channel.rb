# frozen_string_literal: true

module DiscourseCalendar
  module Livestream
    class TopicChatChannel < ActiveRecord::Base
      self.table_name = "livestream_topic_chat_channels"
      belongs_to :topic
      belongs_to :chat_channel, class_name: "Chat::Channel", dependent: :destroy
    end
  end
end
