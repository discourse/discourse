# frozen_string_literal: true

module DiscourseCalendar
  module Livestream
    module TopicExtension
      extend ActiveSupport::Concern

      prepended do
        has_one :topic_chat_channel,
                class_name: "DiscourseCalendar::Livestream::TopicChatChannel",
                dependent: :destroy

        after_update do
          chat_channel = topic_chat_channel&.chat_channel

          next if chat_channel.nil?
          next if chat_channel.chatable_id == category_id

          chat_channel.update!(chatable_id: category_id)
        end
      end
    end
  end
end
