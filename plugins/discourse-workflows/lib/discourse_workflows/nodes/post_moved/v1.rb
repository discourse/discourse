# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostMoved
      class V1 < NodeType
        OUTPUT_SCHEMA =
          Schema.merge(
            Schema::POST_SCHEMA,
            Schema::TOPIC_LIST_ITEM_SCHEMA,
            {
              "$schema" => Schema::DRAFT_URI,
              "type" => "object",
              "properties" => {
                "original_topic" =>
                  Schema::TOPIC_LIST_ITEM_SCHEMA.fetch("properties").fetch("topic"),
              },
            },
          ).freeze

        description(
          name: "trigger:post_moved",
          version: "1.0",
          defaults: {
            icon: "arrows-split-up-and-left",
            color: "deep-orange",
          },
          group: "discourse_triggers",
          event: :post_moved,
          output_contracts: [{ schema: OUTPUT_SCHEMA }],
          properties: {
            **TOPIC_SCOPE_FILTER_PROPERTIES,
          },
        )

        def initialize(post, original_topic_id, *)
          super(parameters: {})
          @post = ::Post.find_by(id: post&.id)
          @original_topic_id = original_topic_id
        end

        def valid?
          @post.present? && destination_topic.present? && original_topic.present? &&
            @post.post_type == ::Post.types[:regular]
        end

        def output
          {
            post: post_data(@post),
            topic: topic_data(destination_topic),
            original_topic: topic_data(original_topic),
          }
        end

        def matches?(trigger_ctx)
          matches_topic_filters?(destination_topic, trigger_ctx)
        end

        private

        def post_data(post)
          serialize_post(post)
        end

        def destination_topic
          @destination_topic ||= ::Topic.find_by(id: @post&.topic_id)
        end

        def original_topic
          @original_topic ||= ::Topic.find_by(id: @original_topic_id)
        end
      end
    end
  end
end
