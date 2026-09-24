# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicPublished
      class V1 < NodeType
        description(
          name: "trigger:topic_published",
          version: "1.0",
          defaults: {
            icon: "calendar-days",
            color: "green",
          },
          group: "discourse_triggers",
          event: :topic_published,
          output_contracts: [
            {
              schema:
                Schema.merge(
                  Schema::TOPIC_LIST_ITEM_SCHEMA,
                  Schema.document(
                    "published_at" => {
                      "type" => "string",
                      "format" => "date-time",
                    },
                  ),
                ),
            },
          ],
          properties: {
            **CATEGORY_FILTER_PROPERTIES,
            **TAG_FILTER_PROPERTIES,
          },
        )

        def initialize(topic, published_at)
          super(parameters: {})
          @topic = topic
          @published_at = published_at
        end

        def valid?
          @topic.present? && @published_at.present?
        end

        def output
          { topic: topic_data(@topic), published_at: @published_at.iso8601 }
        end

        def matches?(trigger_ctx)
          matches_topic_filters?(@topic, trigger_ctx)
        end
      end
    end
  end
end
