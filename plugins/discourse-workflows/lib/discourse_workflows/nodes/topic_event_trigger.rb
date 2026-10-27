# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Triggers on a topic event whose payload carries the user behind it as `acting_user:`, filtered by the
    # topic's category and tags.
    module TopicEventTrigger
      PROPERTIES = {
        **NodeType::CATEGORY_FILTER_PROPERTIES,
        **NodeType::TAG_FILTER_PROPERTIES,
      }.freeze

      OUTPUT_SCHEMA = Schema.merge(Schema::TOPIC_LIST_ITEM_SCHEMA, Schema::ACTOR_SCHEMA)

      def self.description(name:, event:, icon:, color:, i18n_scope:)
        {
          name:,
          version: "1.0",
          defaults: {
            icon:,
            color:,
          },
          group: "discourse_triggers",
          event:,
          i18n_scope:,
          output_contracts: [{ schema: OUTPUT_SCHEMA }],
          properties: PROPERTIES,
        }
      end

      def initialize(topic, payload = {})
        super(parameters: {})
        @topic = topic
        @actor = payload[:acting_user]
      end

      def valid?
        @topic.present?
      end

      def output
        { topic: serialize_topic_list_item(@topic), actor: serialize_user(@actor) }
      end

      def matches?(trigger_ctx)
        matches_topic_filters?(@topic, trigger_ctx)
      end
    end
  end
end
