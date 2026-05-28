# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicClosed
      class V1 < NodeType
        description(
          name: "trigger:topic_closed",
          version: "1.0",
          defaults: {
            icon: "lock",
            color: "grey",
          },
          group: "discourse_triggers",
          events: [:topic_status_updated],
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

        def initialize(topic, status, enabled)
          super(parameters: {})
          @topic = topic
          @status = status
          @enabled = enabled
        end

        def valid?
          @status.to_s == "closed" && @enabled
        end

        def output
          { topic: topic_data(@topic) }
        end

        def matches?(trigger_ctx)
          matches_category?(trigger_ctx.get_node_parameter("category_id")) &&
            matches_tags?(normalize_tag_names(trigger_ctx.get_node_parameter("tag_names")))
        end

        private

        def topic_data(topic)
          serialize_record(topic, TopicListItemSerializer)
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
