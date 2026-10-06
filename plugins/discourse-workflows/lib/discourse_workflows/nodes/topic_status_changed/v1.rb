# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicStatusChanged
      class V1 < NodeType
        STATUS_CHANGES = {
          "closed" => %w[reopened closed],
          "archived" => %w[unarchived archived],
          "visible" => %w[unlisted listed],
          "pinned" => %w[unpinned pinned],
          "pinned_globally" => %w[unpinned_globally pinned_globally],
        }.freeze

        OUTPUT_SCHEMA =
          Schema.merge(
            Schema::TOPIC_LIST_ITEM_SCHEMA,
            Schema.document(
              "status" => {
                "type" => "string",
              },
              "enabled" => {
                "type" => "boolean",
              },
              "change" => {
                "type" => "string",
              },
            ),
          ).freeze

        description(
          name: "trigger:topic_status_changed",
          version: "1.0",
          defaults: {
            icon: "arrows-rotate",
            color: "grey",
          },
          group: "discourse_triggers",
          palette_visible: false,
          event: :topic_status_updated,
          output_contracts: [{ schema: OUTPUT_SCHEMA }],
          properties: {
            statuses: {
              type: :multi_options,
              default: [],
              options: STATUS_CHANGES.values.flatten,
            },
            **CATEGORY_FILTER_PROPERTIES,
            **TAG_FILTER_PROPERTIES,
          },
        )

        def self.description_for_change(change)
          description.merge(
            name: "trigger:topic_#{change}",
            palette_visible: true,
            fixed_change: change,
            i18n_scope: "topic_status_changed",
            properties: properties.except(:statuses),
          )
        end

        def initialize(topic, status, enabled)
          super(parameters: {})
          @topic = topic
          @status = status.to_s == "autoclosed" ? "closed" : status.to_s
          @enabled = enabled
        end

        def valid?
          fixed_change = self.class.description[:fixed_change]
          @topic.present? && STATUS_CHANGES.key?(@status) &&
            (fixed_change.nil? || fixed_change == change)
        end

        def output
          { topic: topic_data(@topic), status: @status, enabled: @enabled, change: change }
        end

        def matches?(trigger_ctx)
          statuses =
            Array.wrap(
              self.class.description[:fixed_change] ||
                trigger_ctx.get_node_parameter("statuses", []),
            ).compact_blank
          return false if statuses.present? && statuses.exclude?(change)

          matches_topic_filters?(@topic, trigger_ctx)
        end

        private

        def change
          STATUS_CHANGES.fetch(@status)[@enabled ? 1 : 0]
        end
      end
    end
  end
end
