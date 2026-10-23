# frozen_string_literal: true

module DiscourseEvents
  module Livestream
    module ChatChannelExtension
      extend ActiveSupport::Concern

      prepended do
        has_one :livestream_topic_chat_channel,
                class_name: "DiscourseEvents::Livestream::TopicChatChannel",
                dependent: :destroy,
                foreign_key: :chat_channel_id
      end
    end
  end
end
