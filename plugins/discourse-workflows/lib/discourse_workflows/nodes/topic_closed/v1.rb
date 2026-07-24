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
          output_contracts: [{ schema: Schema::TOPIC_LIST_ITEM_SCHEMA }],
          properties: {
            category_ids: {
              type: :array,
              required: false,
              ui: {
                control: :category,
                multiple: true,
              },
            },
            include_subcategories: {
              type: :boolean,
              required: false,
              default: true,
              ui: {
                control: :checkbox,
              },
              display_options: {
                show: {
                  category_ids: [{ condition: { exists: true } }],
                },
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
          matches_category_ids?(
            @topic.category_id,
            category_ids_parameter(trigger_ctx),
            include_subcategories: trigger_ctx.get_node_parameter("include_subcategories", true),
          ) && matches_tags?(normalize_tag_names(trigger_ctx.get_node_parameter("tag_names")))
        end

        private

        def topic_data(topic)
          serialize_record(topic, TopicListItemSerializer)
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
