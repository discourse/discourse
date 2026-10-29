# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicTimerChanged
      class V1 < NodeType
        CHANGES = %w[created updated cancelled completed].freeze
        # A palette trigger can cover several reasons: rescheduling a timer is still setting it.
        CHANGE_REASONS = {
          "set" => %w[created updated],
          "cleared" => %w[cancelled],
          "completed" => %w[completed],
        }.freeze

        description(
          name: "trigger:topic_timer_changed",
          version: "1.0",
          defaults: {
            icon: "clock",
            color: "orange",
          },
          group: "discourse_triggers",
          palette_visible: false,
          event: :topic_timer_changed,
          output_contracts: [
            {
              schema:
                Schema.merge(
                  Schema::TOPIC_LIST_ITEM_SCHEMA,
                  Schema::ACTOR_SCHEMA,
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

        # Only setting a timer has a previous one, and several reasons to tell apart.
        def self.description_for_change(change)
          timer_output = { "timer" => Schema::TOPIC_TIMER }
          if change == "set"
            timer_output = {
              "change" => {
                "type" => "string",
                "enum" => CHANGE_REASONS["set"],
              },
              **timer_output,
              "previous_timer" => Schema::NULLABLE_TOPIC_TIMER,
            }
          end

          description.merge(
            name: "trigger:topic_timer_#{change}",
            palette_visible: true,
            fixed_changes: CHANGE_REASONS.fetch(change),
            i18n_scope: "topic_timer_changed",
            output_contracts: [
              {
                schema:
                  Schema.merge(
                    Schema::TOPIC_LIST_ITEM_SCHEMA,
                    Schema::ACTOR_SCHEMA,
                    Schema.document(timer_output),
                  ),
              },
            ],
            properties:
              properties.except(:changes).merge(
                timer_types:
                  properties[:timer_types].merge(
                    options: ::TopicTimer.public_types.keys.map(&:to_s),
                  ),
              ),
          )
        end

        def initialize(timer, change, previous_attributes = nil, payload = {})
          super(parameters: {})
          @timer = timer
          @change = change.to_s
          @previous_attributes = previous_attributes
          @actor = payload[:acting_user]
        end

        # The change is checked first: every timer trigger listens to every timer event. The per-change triggers
        # leave out private timers (slow mode's end has its own triggers).
        def valid?
          return false if CHANGES.exclude?(@change)
          return false if fixed_changes && (fixed_changes.exclude?(@change) || !@timer&.public_type)

          topic.present?
        end

        def output
          data = {
            topic: serialize_topic_list_item(topic),
            actor: serialize_user(@actor),
            change: @change,
            timer: serialize_timer(@timer),
            previous_timer: @previous_attributes && serialize_timer(@timer, @previous_attributes),
          }
          if fixed_changes.nil? || fixed_changes == CHANGE_REASONS["set"]
            data
          else
            data.slice(:topic, :actor, :timer)
          end
        end

        def matches?(trigger_ctx)
          return false if fixed_changes.nil? && !matches_changes?(trigger_ctx, @change)

          types = Array.wrap(trigger_ctx.get_node_parameter("timer_types", []))
          timer_types =
            [@timer.status_type, @previous_attributes&.fetch("status_type", nil)].compact
              .map { |type| ::TopicTimer.types[type].to_s }
          return false if types.present? && !types.intersect?(timer_types)

          matches_topic_filters?(topic, trigger_ctx)
        end

        private

        def topic
          return @topic if defined?(@topic)

          @topic = @timer && ::Topic.with_deleted.find_by(id: @timer.timerable_id)
        end

        def fixed_changes
          self.class.description[:fixed_changes]
        end
      end
    end
  end
end
