# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ListConversations
      include Service::Base

      STARRED_CONVERSATIONS_LIMIT = ConversationStar::MAX_STARS_PER_USER
      DEFAULT_PER_PAGE = 40
      MAX_PER_PAGE = 100

      params do
        attribute :page, :integer, default: 0
        attribute :per_page, :integer, default: DEFAULT_PER_PAGE

        validates :page, numericality: { greater_than_or_equal_to: 0 }
        validates :per_page, numericality: { greater_than: 0, less_than_or_equal_to: MAX_PER_PAGE }
      end

      step :list_conversations

      def self.base_query_for(user)
        Topic
          .private_messages_for_user(user)
          .where(user: user) # Only show PMs where the current user is the author
          .joins(
            "INNER JOIN topic_custom_fields tcf ON tcf.topic_id = topics.id
                 AND tcf.name = '#{DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD}'
                 AND tcf.value = 't'",
          )
          .distinct
      end

      private

      def list_conversations(params:, guardian:)
        if !SiteSetting.enable_ai_bot_starred_conversations
          conversations, has_more =
            paginated_conversations(
              self.class.base_query_for(guardian.user).order(last_posted_at: :desc),
              params.page,
              params.per_page,
            )

          context[:conversations] = conversations
          context[:starred_conversations] = []
          context[:starred_enabled] = false
          context[:starred_at_by_topic_id] = {}
          context[:meta] = meta(params, has_more)
          return
        end

        starred_conversations =
          self
            .class
            .base_query_for(guardian.user)
            .distinct(false)
            .joins(star_join_sql(guardian.user, "INNER JOIN"))
            .order("ai_stars.created_at DESC")
            .limit(STARRED_CONVERSATIONS_LIMIT)
            .to_a

        unstarred_conversations =
          self
            .class
            .base_query_for(guardian.user)
            .joins(star_join_sql(guardian.user, "LEFT JOIN"))
            .where("ai_stars.id IS NULL")
            .distinct

        conversations, has_more =
          paginated_conversations(
            unstarred_conversations.order(last_posted_at: :desc),
            params.page,
            params.per_page,
          )

        context[:conversations] = conversations
        context[:starred_conversations] = params.page == 0 ? starred_conversations : []
        context[:starred_enabled] = true
        context[:starred_at_by_topic_id] = starred_at_by_topic_id(
          guardian.user,
          conversations + context[:starred_conversations],
        )
        context[:meta] = meta(params, has_more)
      end

      def paginated_conversations(relation, page, per_page)
        records = relation.offset(page * per_page).limit(per_page + 1).to_a
        has_more = records.length > per_page
        records = records.first(per_page) if has_more

        [records, has_more]
      end

      def star_join_sql(user, join_type)
        user_id = user.id.to_i
        <<~SQL.squish
          #{join_type} discourse_ai_ai_bot_conversation_stars ai_stars
            ON ai_stars.topic_id = topics.id AND ai_stars.user_id = #{user_id}
        SQL
      end

      def starred_at_by_topic_id(user, topics)
        topic_ids = topics.map(&:id)
        return {} if topic_ids.blank?

        ConversationStar
          .where(user_id: user.id, topic_id: topic_ids)
          .pluck(:topic_id, :created_at)
          .to_h
      end

      def meta(params, has_more)
        { page: params.page, per_page: params.per_page, has_more: has_more }
      end
    end
  end
end
