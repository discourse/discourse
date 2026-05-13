# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ConversationListSerializer < ApplicationSerializer
      attributes :meta

      has_many :conversations, serializer: ConversationListTopicSerializer, embed: :objects

      def conversations
        object.conversations.records
      end

      def meta
        object.meta
      end
    end
  end
end
