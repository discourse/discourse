# frozen_string_literal: true

require "digest"

module DiscourseWorkflows
  module Nodes
    module Schedule
      module Rules
        module_function

        VALID_FIELDS = %w[minutes hours days weeks months cronExpression].freeze

        class Rule
          attr_reader :data

          def initialize(data)
            @data = data.is_a?(Hash) ? data.with_indifferent_access : {}
          end

          def field
            data[:field]
          end

          def expression
            data[:expression]
          end

          def [](key)
            data[key]
          end
        end

        def validate(rules, errors)
          if rules.empty?
            errors.add(:base, I18n.t("discourse_workflows.errors.schedule_rules_required"))
            return
          end

          rules.each do |rule|
            next if valid?(rule)

            errors.add(:base, I18n.t("discourse_workflows.errors.invalid_schedule_rule"))
            break
          end
        end

        def valid?(rule)
          rule = wrap(rule)
          return false if VALID_FIELDS.exclude?(rule.field)

          case rule.field
          when "minutes"
            valid_range?(rule[:minutesInterval], 1..59, allow_nil: true)
          when "hours"
            valid_range?(rule[:hoursInterval], 1..23, allow_nil: true) &&
              valid_range?(rule[:triggerAtMinute], 0..59, allow_nil: true)
          when "days"
            valid_range?(rule[:daysInterval], 1..31, allow_nil: true) &&
              valid_range?(rule[:triggerAtHour], 0..23, allow_nil: true) &&
              valid_range?(rule[:triggerAtMinute], 0..59, allow_nil: true)
          when "weeks"
            valid_range?(rule[:weeksInterval], 1..52, allow_nil: true) &&
              valid_range?(rule[:triggerAtHour], 0..23, allow_nil: true) &&
              valid_range?(rule[:triggerAtMinute], 0..59, allow_nil: true) &&
              valid_weekdays?(rule[:triggerAtDay])
          when "months"
            valid_range?(rule[:monthsInterval], 1..12, allow_nil: true) &&
              valid_range?(rule[:triggerAtDayOfMonth], 1..31, allow_nil: true) &&
              valid_range?(rule[:triggerAtHour], 0..23, allow_nil: true) &&
              valid_range?(rule[:triggerAtMinute], 0..59, allow_nil: true)
          when "cronExpression"
            CronParser.valid?(rule.expression) && CronParser.minute_granularity?(rule.expression)
          end
        end

        def to_cron_expression(rule, node_key = "")
          rule = wrap(rule)

          case rule.field
          when "minutes"
            "*/#{integer_or_default(rule[:minutesInterval], 5).clamp(1, 59)} * * * *"
          when "hours"
            hours = integer_or_default(rule[:hoursInterval], 1).clamp(1, 23)
            minute = integer_or_stable(rule[:triggerAtMinute], node_key, "minute", 0, 60)
            return "#{minute} */#{hours} * * *" if (24 % hours).zero?

            "#{minute} * * * *"
          when "days"
            minute = integer_or_stable(rule[:triggerAtMinute], node_key, "minute", 0, 60)
            hour = integer_or_stable(rule[:triggerAtHour], node_key, "hour", 0, 24)
            "#{minute} #{hour} * * *"
          when "weeks"
            minute = integer_or_stable(rule[:triggerAtMinute], node_key, "minute", 0, 60)
            hour = integer_or_stable(rule[:triggerAtHour], node_key, "hour", 0, 24)
            weekdays = Array.wrap(rule[:triggerAtDay]).map(&:to_i)
            days_of_week = weekdays.empty? ? "*" : weekdays.join(",")
            "#{minute} #{hour} * * #{days_of_week}"
          when "months"
            minute = integer_or_stable(rule[:triggerAtMinute], node_key, "minute", 0, 60)
            hour = integer_or_stable(rule[:triggerAtHour], node_key, "hour", 0, 24)
            day = integer_or_stable(rule[:triggerAtDayOfMonth], node_key, "dayOfMonth", 1, 29)
            months = integer_or_default(rule[:monthsInterval], 1).clamp(1, 12)
            "#{minute} #{hour} #{day} */#{months} *"
          when "cronExpression"
            rule.expression
          end
        end

        def recurrence(rule, index)
          rule = wrap(rule)

          case rule.field
          when "hours"
            DiscourseWorkflows::Nodes::Schedule::Recurrence.for_rule(
              interval_size: integer_or_default(rule[:hoursInterval], 1),
              index:,
              type_interval: "hours",
            )
          when "days"
            DiscourseWorkflows::Nodes::Schedule::Recurrence.for_rule(
              interval_size: integer_or_default(rule[:daysInterval], 1),
              index:,
              type_interval: "days",
            )
          when "weeks"
            DiscourseWorkflows::Nodes::Schedule::Recurrence.for_rule(
              interval_size: integer_or_default(rule[:weeksInterval], 1),
              index:,
              type_interval: "weeks",
            )
          when "months"
            DiscourseWorkflows::Nodes::Schedule::Recurrence.for_rule(
              interval_size: integer_or_default(rule[:monthsInterval], 1),
              index:,
              type_interval: "months",
            )
          else
            DiscourseWorkflows::Nodes::Schedule::Recurrence.inactive
          end
        end

        def wrap(rule)
          rule.is_a?(Rule) ? rule : Rule.new(rule)
        end

        def valid_range?(value, range, allow_nil: false)
          return true if allow_nil && value.nil?

          range.cover?(Integer(value))
        rescue ArgumentError, TypeError
          false
        end

        def valid_weekdays?(days)
          days.blank? || Array.wrap(days).all? { |day| valid_range?(day, 0..6) }
        end

        def integer_or_default(value, default)
          value.nil? ? default : value.to_i
        end

        def integer_or_stable(value, node_key, label, min, max)
          return value.to_i.clamp(min, max - 1) unless value.nil?

          stable_int(node_key, label, min, max)
        end

        def stable_int(seed, label, min, max)
          hash = Digest::SHA256.digest("#{seed}:#{label}")
          min + (hash.unpack1("N") % (max - min))
        end
      end
    end
  end
end
