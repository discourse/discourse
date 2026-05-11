# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class UpdateConversationStar
      include Service::Base

      def self.base_query_for(user)
        ListConversations.base_query_for(user)
      end

      params do
        attribute :topic_id, :integer
        attribute :starred, :boolean

        validates :topic_id, presence: true
        validates :starred, inclusion: { in: [true, false] }
      end

      model :topic
      policy :feature_enabled
      policy :can_access_conversation
      transaction { step :update_star }

      private

      def fetch_topic(params:, guardian:)
        self.class.base_query_for(guardian.user).find_by(id: params.topic_id)
      end

      def feature_enabled
        SiteSetting.enable_ai_bot_starred_conversations
      end

      def can_access_conversation(topic:, guardian:)
        guardian.can_see?(topic) && topic.private_message? && topic.user_id == guardian.user.id &&
          topic.custom_fields[DiscourseAi::AiBot::TOPIC_AI_BOT_PM_FIELD] == "t"
      end

      def update_star(topic:, params:, guardian:)
        if params.starred
          begin
            if DiscourseAi::AiBot::ConversationStar.where(user: guardian.user, topic: topic).exists?
              return
            end

            if DiscourseAi::AiBot::ConversationStar.where(user: guardian.user).count >=
                 DiscourseAi::AiBot::ConversationStar::MAX_STARS_PER_USER
              fail!("maximum starred conversations reached")
            end

            DiscourseAi::AiBot::ConversationStar.find_or_create_by!(
              user: guardian.user,
              topic: topic,
            )
          rescue ActiveRecord::RecordNotUnique
            retry
          end
        else
          DiscourseAi::AiBot::ConversationStar.where(user: guardian.user, topic: topic).delete_all
        end
      end
    end
  end
end
