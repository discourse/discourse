# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module SetSlowMode
      class V1 < NodeType
        include TopicSlowMode

        INTERVAL_UNITS = %w[seconds minutes hours days].freeze

        description(
          TopicSlowMode.description(
            name: "action:set_slow_mode",
            icon: "hourglass-start",
            properties: {
              interval: {
                type: :integer,
                required: true,
                default: 10,
              },
              interval_unit: {
                type: :options,
                required: true,
                default: "minutes",
                options: INTERVAL_UNITS,
              },
              enabled_until: {
                type: :string,
                required: false,
                ui: {
                  control: :date_time,
                },
              },
              **NodeType.timezone_property(
                none: "discourse_workflows.topic_slow_mode.timezone_none",
              ),
            },
            output: TopicSlowMode::OUTPUT,
          ),
        )

        def self.validate_configuration(configuration, errors)
          validate_timezone_configuration(configuration, errors)

          configuration = (configuration || {}).deep_stringify_keys
          interval = configuration.fetch("interval", 10)
          unit = configuration.fetch("interval_unit", "minutes")
          return if expression_value?(interval) || expression_value?(unit)

          if INTERVAL_UNITS.exclude?(unit.to_s)
            errors.add(
              :base,
              I18n.t(
                "discourse_workflows.errors.topic_slow_mode.invalid_interval_unit",
                interval_unit: unit,
              ),
            )
          elsif interval_in_seconds(interval, unit).nil?
            errors.add(:base, interval_error(interval))
          end
        end

        def self.interval_in_seconds(interval, unit)
          amount = Integer(interval.to_s, 10, exception: false)
          seconds = amount && amount.public_send(unit).to_i
          seconds if seconds&.between?(1, ::Topic::UpdateSlowMode::MAX_SECONDS)
        end

        def self.interval_error(interval)
          I18n.t(
            "discourse_workflows.errors.topic_slow_mode.invalid_interval",
            value: interval,
            max_days: ::Topic::UpdateSlowMode::MAX_SECONDS / 1.day.to_i,
          )
        end

        private

        def change(exec_ctx, topic, actor, item_index)
          seconds = interval_seconds(exec_ctx, item_index)
          enabled_until =
            parse_time_in_timezone(
              exec_ctx,
              exec_ctx.get_node_parameter("enabled_until", item_index),
              item_index:,
              field: "enabled_until",
              error_key: "discourse_workflows.errors.topic_slow_mode.invalid_time",
            )

          before = slow_mode(topic)
          update_slow_mode(
            topic,
            actor,
            item_index,
            seconds:,
            enabled_until: enabled_until&.iso8601,
          )
          after = slow_mode(topic)

          {
            topic: serialize_topic(topic, guardian: actor.guardian),
            slow_mode_seconds: topic.slow_mode_seconds,
            slow_mode_enabled_until: topic.slow_mode_topic_timer&.execute_at&.utc&.iso8601,
            changed: after != before,
          }
        end

        def interval_seconds(exec_ctx, item_index)
          interval = exec_ctx.get_node_parameter("interval", item_index, default: 10)
          unit = exec_ctx.get_node_parameter("interval_unit", item_index, default: "minutes").to_s
          if INTERVAL_UNITS.exclude?(unit)
            slow_mode_error!("invalid_interval_unit", item_index, interval_unit: unit)
          end

          self.class.interval_in_seconds(interval, unit) ||
            raise_node_error!(self.class.interval_error(interval), item_index:)
        end

        def slow_mode(topic)
          [topic.slow_mode_seconds, topic.slow_mode_topic_timer&.execute_at&.to_i]
        end
      end
    end
  end
end
