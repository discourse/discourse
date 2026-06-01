# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicCreated
      class V1 < NodeType
        description(
          name: "trigger:topic_created",
          version: "1.0",
          defaults: {
            icon: "plus",
            color: "teal",
          },
          group: "discourse_triggers",
          events: [:topic_created],
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

        def initialize(topic, opts = nil, *)
          super(parameters: {})
          @topic = topic
          @opts = opts
        end

        def valid?
          @topic.present? && !@opts&.dig(:skip_workflows)
        end

        def output
          { post: post_data(@topic.first_post), topic: topic_data(@topic) }
        end

        def matches?(trigger_ctx)
          matches_category?(trigger_ctx.get_node_parameter("category_id")) &&
            matches_tags?(normalize_tag_names(trigger_ctx.get_node_parameter("tag_names")))
        end

        private

        def topic_data(topic)
          serialize_record(topic, TopicListItemSerializer)
        end

        def post_data(post)
          serialize_record(post, WebHookPostSerializer)
        end

        def matches_category?(category_id)
          category_id.blank? || @topic.category_id == category_id.to_i
        end

        def matches_tags?(tag_names)
          tag_names.empty? || (topic_tag_names & tag_names).any?
        end

        def topic_tag_names
          @topic_tag_names ||= @topic.tags.pluck(:name)
        end
      end
    end
  end
end
