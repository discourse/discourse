# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Schedule
      module Recurrence
        module_function

        def inactive
          { activated: false }
        end

        def for_rule(interval_size:, index:, type_interval:)
          return inactive if interval_size == 1

          {
            activated: true,
            index: index,
            interval_size: interval_size,
            type_interval: type_interval,
          }
        end

        def due?(recurrence, recurrence_rules, scheduled_at, timezone)
          return true if !recurrence[:activated]

          index = recurrence[:index]
          current_value = value(recurrence, scheduled_at, timezone)
          last_value = recurrence_rules[index]

          return update!(recurrence_rules, index, current_value) if last_value.nil?

          last_value = last_value.to_i
          interval_size = recurrence[:interval_size]
          due =
            case recurrence[:type_interval]
            when "hours"
              exact_interval_match?(current_value, last_value, interval_size, 24)
            when "days"
              exact_interval_match?(current_value, last_value, interval_size, 365)
            when "weeks"
              exact_interval_match?(current_value, last_value, interval_size, 52) ||
                current_value == last_value
            when "months"
              exact_interval_match?(current_value, last_value, interval_size, 12)
            else
              false
            end

          update!(recurrence_rules, index, current_value) if due
          due
        end

        def value(recurrence, scheduled_at, timezone)
          local_time = scheduled_at.in_time_zone(timezone)

          case recurrence[:type_interval]
          when "hours"
            local_time.hour
          when "days"
            local_time.yday
          when "weeks"
            local_time.to_date.strftime("%U").to_i + 1
          when "months"
            local_time.month - 1
          end
        end

        def update!(recurrence_rules, index, value)
          recurrence_rules[index] = value
          true
        end

        def exact_interval_match?(current_value, last_value, interval_size, modulus)
          expected_difference = interval_size % modulus
          (current_value - last_value + modulus) % modulus == expected_difference
        end
      end
    end
  end
end
