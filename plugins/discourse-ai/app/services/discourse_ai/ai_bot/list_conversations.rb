# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ListConversations
      include Service::Base

      DEFAULT_PER_PAGE = 40
      MAX_PER_PAGE = 100

      params do
        attribute :page, :integer, default: 0
        attribute :per_page, :integer, default: DEFAULT_PER_PAGE

        validates :page, numericality: { greater_than_or_equal_to: 0 }
        validates :per_page, numericality: { greater_than: 0, less_than_or_equal_to: MAX_PER_PAGE }
      end

      model :list_result, :fetch_list_result
      model :conversations, :fetch_conversations
      model :meta, :fetch_meta
      model :starred_at_by_topic_id, :fetch_starred_at_by_topic_id, optional: true

      private

      def fetch_list_result(params:, guardian:)
        ConversationStar.list(guardian.user, page: params.page, per_page: params.per_page)
      end

      def fetch_conversations(list_result:)
        list_result.conversations
      end

      def fetch_meta(list_result:)
        list_result.meta
      end

      def fetch_starred_at_by_topic_id(list_result:)
        list_result.starred_at_by_topic_id
      end
    end
  end
end
