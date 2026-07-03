# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostMoved
      class V1 < NodeType
        description(
          name: "trigger:post_moved",
          version: "1.0",
          defaults: {
            icon: "arrows-split-up-and-left",
            color: "deep-orange",
          },
          group: "discourse_triggers",
          events: [:post_moved],
          properties: {
            category_id: {
              type: :integer,
              required: false,
              ui: {
                control: :category,
              },
            },
            tag_names: {
              type: :string,
              required: false,
              ui: {
                control: :tags,
              },
            },
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
          matches_category?(trigger_ctx.get_node_parameter("category_id")) &&
            matches_tags?(normalize_tag_names(trigger_ctx.get_node_parameter("tag_names")))
        end

        private

        def post_data(post)
          serialize_post(post)
        end

        def topic_data(topic)
          serialize_record(topic, TopicListItemSerializer)
        end

        def destination_topic
          @destination_topic ||= ::Topic.find_by(id: @post&.topic_id)
        end

        def original_topic
          @original_topic ||= ::Topic.find_by(id: @original_topic_id)
        end

        def matches_category?(category_id)
          category_id.blank? || destination_topic.category_id == category_id.to_i
        end

        def matches_tags?(tag_names)
          tag_names.empty? || (destination_topic_tag_names & tag_names).any?
        end

        def destination_topic_tag_names
          @destination_topic_tag_names ||= destination_topic.tags.pluck(:name)
        end
      end
    end
  end
end
