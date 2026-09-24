# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicTimerChanged
      class V1 < NodeType
        CHANGES = %w[created updated cancelled completed].freeze
        TIMER_PROPERTIES = {
          "id" => {
            "type" => "integer",
          },
          "status_type" => {
            "type" => "string",
          },
          "execute_at" => {
            "type" => "string",
            "format" => "date-time",
          },
          "category_id" => {
            "type" => %w[integer null],
          },
          "user_id" => {
            "type" => "integer",
          },
          "based_on_last_post" => {
            "type" => "boolean",
          },
          "duration_minutes" => {
            "type" => %w[integer null],
          },
        }.freeze

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
                    "timer" => {
                      "type" => "object",
                      "properties" => TIMER_PROPERTIES,
                    },
                    "previous_timer" => {
                      "type" => %w[object null],
                      "properties" => TIMER_PROPERTIES,
                    },
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
            topic: topic_data(@topic),
            change: @change,
            timer: timer_data(@timer.attributes),
            previous_timer: @previous_attributes && timer_data(@previous_attributes),
          }
        end

        def matches?(trigger_ctx)
          changes = Array.wrap(trigger_ctx.get_node_parameter("changes", []))
          return false if changes.present? && !changes.include?(@change)

          types = Array.wrap(trigger_ctx.get_node_parameter("timer_types", []))
          timer_types =
            [@timer.status_type, @previous_attributes&.fetch("status_type", nil)].compact
              .map { |type| ::TopicTimer.types[type].to_s }
          return false if types.present? && !types.intersect?(timer_types)

          matches_topic_filters?(@topic, trigger_ctx)
        end

        private

        def timer_data(attributes)
          attributes.slice(*::TopicTimer::EVENT_ATTRIBUTES).merge(
            "id" => @timer.id,
            "status_type" => ::TopicTimer.types[attributes["status_type"]].to_s,
            "execute_at" => attributes["execute_at"].iso8601,
          )
        end
      end
    end
  end
end
