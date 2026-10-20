# frozen_string_literal: true

module DiscourseAi
  module Discoveries
    class EntryPoint
      def inject_into(plugin)
        UserUpdater::OPTION_ATTR.push(:ai_ask_ai_default)

        %i[user_option current_user_option].each do |serializer|
          plugin.add_to_serializer(
            serializer,
            :ai_ask_ai_default,
            include_condition: -> { SiteSetting.ai_ask_ai_enabled && scope.authenticated? },
          ) { object.ai_ask_ai_default }
        end

        # A conversation continued from a combined search lists the topics
        # behind it in place of the timeline.
        plugin.add_to_serializer(
          :topic_view,
          :ai_search_conversation,
          include_condition: -> do
            object.topic.private_message? &&
              object.topic.custom_fields[ContinueConversation::TOPIC_REQUEST_ID_FIELD].present?
          end,
        ) { true }

        plugin.add_to_serializer(
          :topic_view,
          :ai_search_scope,
          include_condition: -> do
            object.topic.private_message? &&
              object.topic.custom_fields[ContinueConversation::TOPIC_SCOPE_FIELD].present?
          end,
        ) { object.topic.custom_fields[ContinueConversation::TOPIC_SCOPE_FIELD] }
      end
    end
  end
end
