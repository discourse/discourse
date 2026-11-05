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

        plugin.register_topic_custom_field_type(ContinueConversation::TOPIC_SOURCES_FIELD, :json)

        # A conversation continued from a combined search lists the topics it
        # cites in place of the timeline.
        plugin.add_to_serializer(
          :topic_view,
          :ai_search_conversation,
          include_condition: -> do
            object.topic.private_message? &&
              object.topic.custom_fields[ContinueConversation::TOPIC_REQUEST_ID_FIELD].present?
          end,
        ) { true }

        # sent with the conversation, so the list shows without loading it
        plugin.add_to_serializer(
          :topic_view,
          :ai_search_cited_topics,
          include_condition: -> do
            object.topic.private_message? &&
              object.topic.custom_fields[ContinueConversation::TOPIC_REQUEST_ID_FIELD].present?
          end,
        ) { CitedTopics.new(topic: object.topic, guardian: scope).as_json }
      end
    end
  end
end
