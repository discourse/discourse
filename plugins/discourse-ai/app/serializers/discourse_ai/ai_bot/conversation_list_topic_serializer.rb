# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ConversationListTopicSerializer < ::ListableTopicSerializer
      attributes :ai_conversation_starred, :ai_conversation_starred_at

      def ai_conversation_starred
        starred_at.present?
      end

      def ai_conversation_starred_at
        starred_at&.iso8601
      end

      private

      def starred_at
        @starred_at ||=
          begin
            return if @options[:starred_at_by_topic_id].blank?

            @options[:starred_at_by_topic_id][object.id]
          end
      end
    end
  end
end
