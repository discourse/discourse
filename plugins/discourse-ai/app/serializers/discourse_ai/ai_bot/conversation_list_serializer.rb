# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ConversationListSerializer < ApplicationSerializer
      attributes :meta

      has_many :conversations, serializer: ConversationListTopicSerializer, embed: :objects
      has_many :starred_conversations, serializer: ConversationListTopicSerializer, embed: :objects

      def conversations
        object.conversations.records
      end

      def starred_conversations
        object.starred_conversations
      end

      def include_starred_conversations?
        object.starred_conversations.present?
      end

      def meta
        object.meta
      end
    end
  end
end
