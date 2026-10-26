# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicTimerChanged
      class V1 < NodeType
        CHANGES = %w[created updated cancelled completed].freeze

        description(
          name: "trigger:topic_timer_changed",
          version: "1.0",
          defaults: {
            icon: "clock",
            color: "orange",
          },
          group: "discourse_triggers",
          event: :topic_timer_changed,
          output_contracts: [
            {
              schema:
                Schema.merge(
                  Schema::TOPIC_LIST_ITEM_SCHEMA,
                  Schema.document(
                    "change" => {
                      "type" => "string",
                      "enum" => CHANGES,
                    },
                    "timer" => Schema::TOPIC_TIMER,
                    "previous_timer" => Schema::NULLABLE_TOPIC_TIMER,
                  ),
                ),
            },
          ],
          properties: {
            changes: {
              type: :multi_options,
              required: false,
              default: [],
              options: CHANGES,
            },
            timer_types: {
              type: :multi_options,
              required: false,
              default: [],
              options: ::TopicTimer.types.keys.map(&:to_s),
            },
            **CATEGORY_FILTER_PROPERTIES,
            **TAG_FILTER_PROPERTIES,
          },
        )

        def initialize(timer, change, previous_attributes = nil)
          super(parameters: {})
          @timer = timer
          @topic = ::Topic.with_deleted.find_by(id: timer.timerable_id) if timer
          @change = change.to_s
          @previous_attributes = previous_attributes
        end

        def valid?
          @topic.present? && CHANGES.include?(@change)
        end

        def output
          {
            topic: serialize_topic_list_item(@topic),
            change: @change,
            timer: serialize_timer(@timer),
            previous_timer: @previous_attributes && serialize_timer(@timer, @previous_attributes),
          }
        end

        def matches?(trigger_ctx)
          return false if !matches_changes?(trigger_ctx, @change)

          types = Array.wrap(trigger_ctx.get_node_parameter("timer_types", []))
          timer_types =
            [@timer.status_type, @previous_attributes&.fetch("status_type", nil)].compact
              .map { |type| ::TopicTimer.types[type].to_s }
          return false if types.present? && !types.intersect?(timer_types)

          matches_topic_filters?(@topic, trigger_ctx)
        end
      end
    end
  end
end
