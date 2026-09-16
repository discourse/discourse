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
          event: :topic_status_updated,
          output_contracts: [{ schema: Schema::TOPIC_LIST_ITEM_SCHEMA }],
          properties: {
            **CATEGORY_FILTER_PROPERTIES,
            **TAG_FILTER_PROPERTIES,
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
          ) &&
            matches_tags?(@topic, normalize_tag_names(trigger_ctx.get_node_parameter("tag_names")))
        end
      end
    end
  end
end
