# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class UpdateConversationStar
      include Service::Base

      class StrictBoolean < ActiveModel::Type::Boolean
        def cast(value)
          case value
          when true, false
            value
          when "true"
            true
          when "false"
            false
          end
        end
      end

      policy :feature_enabled

      params do
        attribute :topic_id, :integer
        attribute :starred, StrictBoolean.new

        validates :topic_id, presence: true
        validates :starred, inclusion: { in: [true, false] }
      end

      model :user, :fetch_user
      model :topic
      policy :can_access_conversation

      only_if :star_conversation_requested do
        policy :not_already_starred

        lock :user do
          transaction do
            step :ensure_user_can_star_more_conversations
            model :conversation_star, :create_conversation_star
          end
        end
      end

      only_if :unstar_conversation_requested do
        step :unstar_conversation
      end

      private

      def feature_enabled
        SiteSetting.enable_ai_bot_starred_conversations
      end

      def fetch_user(guardian:)
        guardian.user
      end

      def fetch_topic(params:, guardian:)
        ConversationStar.conversations_query_for(guardian.user).find_by(id: params.topic_id)
      end

      def can_access_conversation(topic:, guardian:)
        guardian.can_see?(topic) && topic.private_message? && topic.user_id == guardian.user.id &&
          topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD] == "t"
      end

      def star_conversation_requested(params:)
        params.starred
      end

      def unstar_conversation_requested(params:)
        !params.starred
      end

      def not_already_starred(user:, topic:)
        !ConversationStar.exists?(user:, topic:)
      end

      def ensure_user_can_star_more_conversations(user:)
        if ConversationStar.user_reached_star_limit?(user)
          fail!("maximum starred conversations reached")
        end
      end

      def create_conversation_star(user:, topic:)
        ConversationStar.create_or_find_by(user:, topic:)
      end

      def unstar_conversation(user:, topic:)
        ConversationStar.where(user:, topic:).delete_all
      end
    end
  end
end
