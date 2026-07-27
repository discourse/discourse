# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ConversationStar < ActiveRecord::Base
      MAX_STARS_PER_USER = 200
      ConversationPage =
        Data.define(:records, :has_more) do
          def self.paginate(relation, page:, per_page:)
            records = relation.offset(page * per_page).limit(per_page + 1).to_a
            has_more = records.length > per_page
            records = records.first(per_page) if has_more

            new(records:, has_more:)
          end
        end
      ConversationList = Data.define(:conversations, :meta, :starred_at_by_topic_id)

      self.table_name = "discourse_ai_ai_bot_conversation_stars"

      belongs_to :user
      belongs_to :topic, -> { with_deleted }

      validates :user_id, presence: true
      validates :topic_id, presence: true, uniqueness: { scope: :user_id }

      def self.conversations_query_for(user)
        Topic
          .private_messages_for_user(user)
          .where(user: user)
          .joins(Topic.ai_conversation_custom_field_join_sql)
          .distinct
      end

      def self.starred_conversations_for(user, limit: MAX_STARS_PER_USER)
        conversations_query_for(user)
          .distinct(false)
          .joins(:ai_conversation_stars)
          .where(discourse_ai_ai_bot_conversation_stars: { user: user })
          .order("discourse_ai_ai_bot_conversation_stars.created_at DESC")
          .limit(limit)
      end

      def self.unstarred_conversations_for(user)
        starred_topic_ids = where(user: user).select(:topic_id)
        conversations_query_for(user).where.not(id: starred_topic_ids)
      end

      def self.list(user, page: 0, per_page: 40)
        starred = page == 0 ? starred_conversations_for(user).to_a : []
        unstarred_relation = unstarred_conversations_for(user)

        unstarred_page =
          ConversationPage.paginate(
            unstarred_relation.order(last_posted_at: :desc),
            page: page,
            per_page: per_page,
          )

        all_topics = starred + unstarred_page.records

        starred_lookup = starred_at_by_topic_id(user, all_topics)

        conversations =
          ConversationPage.new(
            records: starred + unstarred_page.records,
            has_more: unstarred_page.has_more,
          )

        ConversationList.new(
          conversations:,
          meta: {
            page: page,
            per_page: per_page,
            has_more: unstarred_page.has_more,
          },
          starred_at_by_topic_id: starred_lookup,
        )
      end

      def self.starred_at_by_topic_id(user, topics)
        topic_ids = topics.map(&:id)
        return {} if topic_ids.blank?

        where(user_id: user.id, topic_id: topic_ids).pluck(:topic_id, :created_at).to_h
      end

      def self.user_reached_star_limit?(user)
        where(user: user).count >= MAX_STARS_PER_USER
      end
    end
  end
end

# == Schema Information
#
# Table name: discourse_ai_ai_bot_conversation_stars
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  topic_id   :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  idx_ai_bot_conversation_stars_topic_id      (topic_id)
#  idx_ai_bot_conversation_stars_user_created  (user_id,created_at)
#  idx_ai_bot_conversation_stars_user_topic    (user_id,topic_id) UNIQUE
#
