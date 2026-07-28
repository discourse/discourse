# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicCategoryChanged
      class V1 < NodeType
        OUTPUT_SCHEMA =
          Schema.merge(
            Schema::TOPIC_LIST_ITEM_SCHEMA,
            {
              "$schema" => Schema::DRAFT_URI,
              "type" => "object",
              "properties" => {
                "old_category_id" => {
                  "type" => "integer",
                },
              },
            },
          ).freeze

        description(
          name: "trigger:topic_category_changed",
          version: "1.0",
          defaults: {
            icon: "folder-open",
            color: "deep-orange",
          },
          group: "discourse_triggers",
          events: [:topic_category_changed],
          output_contracts: [{ schema: OUTPUT_SCHEMA }],
        )

        def initialize(topic, old_category)
          super(parameters: {})
          @topic = topic
          @old_category = old_category
        end

        def valid?
          @topic.present? && @old_category.present?
        end

        def output
          { topic: topic_data(@topic), old_category_id: @old_category.id }
        end

        private

        def topic_data(topic)
          serialize_record(topic, TopicListItemSerializer)
        end
      end
    end
  end
end
