# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicTagChanged
      class V1 < NodeType
        TAG_LIST_SCHEMA = { "type" => "array", "items" => { "type" => "string" } }.freeze
        OUTPUT_SCHEMA =
          Schema.merge(
            Schema::TOPIC_LIST_ITEM_SCHEMA,
            {
              "$schema" => Schema::DRAFT_URI,
              "type" => "object",
              "properties" =>
                %w[old_tags new_tags added_tags removed_tags].index_with { TAG_LIST_SCHEMA },
            },
          ).freeze

        description(
          name: "trigger:topic_tag_changed",
          version: "1.0",
          defaults: {
            icon: "tag",
            color: "deep-orange",
          },
          group: "discourse_triggers",
          events: [:topic_tags_changed],
          output_contracts: [{ schema: OUTPUT_SCHEMA }],
          properties: {
            category_id: {
              type: :integer,
              required: false,
              ui: {
                control: :category,
              },
            },
          },
        )

        def initialize(topic, payload = {})
          super(parameters: {})
          @topic = topic
          @old_tag_names = payload[:old_tag_names] || []
          @new_tag_names = payload[:new_tag_names] || []
          @user = payload[:user]
        end

        def valid?
          @topic.present? && (added_tags.present? || removed_tags.present?)
        end

        def output
          {
            topic: topic_data(@topic),
            old_tags: @old_tag_names,
            new_tags: @new_tag_names,
            added_tags: added_tags,
            removed_tags: removed_tags,
          }
        end

        def matches?(trigger_ctx)
          matches_category?(trigger_ctx.get_node_parameter("category_id"))
        end

        private

        def added_tags
          @new_tag_names - @old_tag_names
        end

        def removed_tags
          @old_tag_names - @new_tag_names
        end

        def topic_data(topic)
          serialize_record(topic, TopicListItemSerializer)
        end

        def matches_category?(category_id)
          category_id.blank? || @topic.category_id == category_id.to_i
        end
      end
    end
  end
end
