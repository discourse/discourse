# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TimeWindow
      class V1 < NodeType
        WEEKDAY_OPTIONS = [1, 2, 3, 4, 5, 6, 0].freeze
        WEEKDAYS = (1..5).to_a.freeze
        WEEKENDS = [0, 6].freeze
        DAY_MODES = %w[all weekdays weekends custom].freeze
        TIME_FORMAT = /\A(\d{1,2}):(\d{2})\z/

        description(
          name: "condition:time_window",
          version: "1.0",
          defaults: {
            icon: "business-time",
            color: "blue",
          },
          outputs: [
            { key: "true", label_key: "discourse_workflows.branch.true" },
            { key: "false", label_key: "discourse_workflows.branch.false" },
          ],
          capabilities: {
            run_scope: "per_item",
          },
          output_contracts: [{ mode: :passthrough }, { mode: :passthrough }],
          properties: {
            day_mode: {
              type: :options,
              options: DAY_MODES,
              default: "all",
              no_data_expression: true,
            },
            days: {
              type: :multi_options,
              default: [1, 2, 3, 4, 5],
              options: WEEKDAY_OPTIONS,
              display_options: {
                show: {
                  day_mode: %w[custom],
                },
              },
              control_options: {
                option_format: :weekday,
              },
            },
            use_time_range: {
              type: :boolean,
              default: false,
            },
            start_time: {
              type: :string,
              default: "09:00",
              display_options: {
                show: {
                  use_time_range: [true],
                },
              },
              ui: {
                control: :time,
              },
            },
            end_time: {
              type: :string,
              default: "17:00",
              display_options: {
                show: {
                  use_time_range: [true],
                },
              },
              ui: {
                control: :time,
              },
            },
            timezone: {
              type: :string,
              ui: {
                control: :timezone,
              },
              control_options: {
                none: "discourse_workflows.time_window.timezone_none",
              },
            },
          },
        )

        def self.validate_configuration(configuration, errors)
          config = (configuration || {}).deep_stringify_keys

          day_mode = config["day_mode"].presence || "all"
          if DAY_MODES.exclude?(day_mode.to_s)
            errors.add(
              :base,
              I18n.t("discourse_workflows.errors.time_window.invalid_day_mode", mode: day_mode),
            )
          end

          if day_mode.to_s == "custom"
            days = Array.wrap(config["days"])
            if days.empty?
              errors.add(:base, I18n.t("discourse_workflows.errors.time_window.days_required"))
            elsif days.any? { |day| !valid_wday?(day) }
              errors.add(:base, I18n.t("discourse_workflows.errors.time_window.invalid_days"))
            end
          end

          if ActiveModel::Type::Boolean.new.cast(config["use_time_range"])
            start_value = config["start_time"]
            end_value = config["end_time"]
            static_values = [start_value, end_value].reject { |value| expression?(value) }

            if static_values.any? { |value| parse_minutes(value).nil? }
              errors.add(:base, I18n.t("discourse_workflows.errors.time_window.invalid_time_range"))
            elsif static_values.size == 2 && parse_minutes(start_value) == parse_minutes(end_value)
              errors.add(:base, I18n.t("discourse_workflows.errors.time_window.start_end_equal"))
            end
          end

          timezone = config["timezone"].presence
          if timezone && !expression?(timezone) && !WorkflowTimezone.valid?(timezone)
            errors.add(
              :base,
              I18n.t("discourse_workflows.errors.time_window.invalid_timezone", timezone: timezone),
            )
          end
        end

        def self.expression?(value)
          value.is_a?(String) && value.start_with?("=")
        end

        def self.valid_wday?(value)
          (0..6).cover?(Integer(value))
        rescue ArgumentError, TypeError
          false
        end

        def self.parse_minutes(value)
          match = TIME_FORMAT.match(value.to_s.strip)
          return if match.nil?

          hour = match[1].to_i
          minute = match[2].to_i
          return if hour > 23 || minute > 59

          hour * 60 + minute
        end

        def execute(exec_ctx)
          now = Time.zone.now

          exec_ctx
            .input_items
            .each_with_index
            .partition { |_item, item_index| within_window?(exec_ctx, item_index, now) }
            .map { |items| items.map(&:first) }
        end

        private

        def within_window?(exec_ctx, item_index, now)
          local_now = now.in_time_zone(resolve_timezone(exec_ctx, item_index))
          exec_ctx.log.kv("local_time", local_now.strftime("%A %H:%M (%Z)")) if item_index.zero?
          day_match?(exec_ctx, item_index, local_now) &&
            time_match?(exec_ctx, item_index, local_now)
        end

        def day_match?(exec_ctx, item_index, local_now)
          mode = exec_ctx.get_node_parameter("day_mode", item_index, default: "all").to_s

          case mode
          when "all"
            true
          when "weekdays"
            WEEKDAYS.include?(local_now.wday)
          when "weekends"
            WEEKENDS.include?(local_now.wday)
          when "custom"
            Array
              .wrap(exec_ctx.get_node_parameter("days", item_index, default: []))
              .map(&:to_i)
              .include?(local_now.wday)
          else
            raise_node_error!(
              I18n.t("discourse_workflows.errors.time_window.invalid_day_mode", mode: mode),
              item_index: item_index,
            )
          end
        end

        def time_match?(exec_ctx, item_index, local_now)
          return true if !exec_ctx.get_node_parameter("use_time_range", item_index, default: false)

          start_minutes = minutes_of_day!(exec_ctx, "start_time", item_index)
          end_minutes = minutes_of_day!(exec_ctx, "end_time", item_index)
          current_minutes = local_now.hour * 60 + local_now.min

          if start_minutes < end_minutes
            current_minutes >= start_minutes && current_minutes < end_minutes
          elsif start_minutes > end_minutes
            current_minutes >= start_minutes || current_minutes < end_minutes
          else
            false
          end
        end

        def minutes_of_day!(exec_ctx, field, item_index)
          value = exec_ctx.get_node_parameter(field, item_index, default: nil)
          minutes = self.class.parse_minutes(value)

          if minutes.nil?
            raise_node_error!(
              I18n.t(
                "discourse_workflows.errors.time_window.invalid_time",
                field: field,
                value: value.to_s,
              ),
              item_index: item_index,
            )
          end

          minutes
        end

        def resolve_timezone(exec_ctx, item_index)
          timezone = exec_ctx.get_node_parameter("timezone", item_index, default: nil).to_s.presence
          return exec_ctx.get_timezone if timezone.nil?

          if !WorkflowTimezone.valid?(timezone)
            raise_node_error!(
              I18n.t("discourse_workflows.errors.time_window.invalid_timezone", timezone: timezone),
              item_index: item_index,
            )
          end

          timezone
        end
      end
    end
  end
end
