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

      model :conversations

      only_if :starred_enabled? do
        model :starred_conversations, optional: true
      end

      only_if :starred_disabled? do
        model :starred_conversations, :fetch_empty_starred_conversations, optional: true
      end

      step :build_meta

      private

      def fetch_conversations(params:, guardian:)
        relation =
          if starred_enabled?
            ConversationStar.unstarred_conversations_for(guardian.user)
          else
            ConversationStar.conversations_query_for(guardian.user)
          end

        ConversationStar.paginated_conversations(
          relation.order(last_posted_at: :desc),
          page: params.page,
          per_page: params.per_page,
        )
      end

      def fetch_starred_conversations(params:, guardian:)
        return [] if params.page > 0

        ConversationStar.starred_conversations_for(guardian.user).to_a
      end

      def fetch_empty_starred_conversations
        []
      end

      def build_meta(params:, conversations:)
        context[:meta] = {
          page: params.page,
          per_page: params.per_page,
          has_more: conversations.has_more,
        }
      end

      def starred_enabled?
        SiteSetting.enable_ai_bot_starred_conversations
      end

      def starred_disabled?
        !starred_enabled?
      end
    end
  end
end
