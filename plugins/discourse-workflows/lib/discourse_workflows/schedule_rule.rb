# frozen_string_literal: true

module DiscourseWorkflows
  module ScheduleRule
    module_function

    VALID_INTERVALS = %w[seconds minutes hours days weeks months cron].freeze

    MAX_RULES_PER_NODE = 5

    WEEKDAY_MAP = {
      0 => "SU",
      1 => "MO",
      2 => "TU",
      3 => "WE",
      4 => "TH",
      5 => "FR",
      6 => "SA",
    }.freeze

    class Rule
      attr_reader :data

      def initialize(raw)
        @data = raw.is_a?(Hash) ? raw.with_indifferent_access : raw
      end

      def interval
        @data[:interval]
      end

      def cron
        @data[:cron]
      end

      def [](key)
        @data[key]
      end

      def fetch(key, *args, &block)
        @data.fetch(key, *args, &block)
      end

      def handler
        INTERVAL_HANDLERS.fetch(interval) { INTERVAL_HANDLERS.fetch("seconds") }
      end
    end

    module IntervalHandler
      class Seconds
        def to_rrule(_rule) = nil

        def valid?(rule)
          n = (rule[:seconds_between_triggers] || 30).to_i
          n >= 1 && n <= 59
        end

        def matches_now?(_rule, _dtstart, _now) = false

        def effective_dtstart(_created, now) = now
      end

      class Minutes
        def to_rrule(rule)
          n = (rule[:minutes_between_triggers] || 5).to_i.clamp(1, 59)
          "FREQ=MINUTELY;INTERVAL=#{n}"
        end

        def valid?(rule) = to_rrule(rule).present?

        def matches_now?(rule, dtstart, now)
          ScheduleRule.rrule_matches?(to_rrule(rule), effective_dtstart(dtstart, now), now)
        end

        def effective_dtstart(_created, now) = now.beginning_of_day
      end

      class Hours
        def to_rrule(rule)
          n = (rule[:hours_between_triggers] || 1).to_i.clamp(1, 23)
          minute = (rule[:trigger_at_minute] || 0).to_i.clamp(0, 59)
          "FREQ=HOURLY;INTERVAL=#{n};BYMINUTE=#{minute}"
        end

        def valid?(rule) = to_rrule(rule).present?

        def matches_now?(rule, dtstart, now)
          ScheduleRule.rrule_matches?(to_rrule(rule), effective_dtstart(dtstart, now), now)
        end

        def effective_dtstart(_created, now) = now.beginning_of_day
      end

      class Days
        def to_rrule(rule)
          n = (rule[:days_between_triggers] || 1).to_i.clamp(1, 31)
          hour = (rule[:trigger_at_hour] || 0).to_i.clamp(0, 23)
          minute = (rule[:trigger_at_minute] || 0).to_i.clamp(0, 59)
          "FREQ=DAILY;INTERVAL=#{n};BYHOUR=#{hour};BYMINUTE=#{minute}"
        end

        def valid?(rule) = to_rrule(rule).present?

        def matches_now?(rule, dtstart, now)
          ScheduleRule.rrule_matches?(to_rrule(rule), effective_dtstart(dtstart, now), now)
        end

        def effective_dtstart(created, _now) = created.utc.beginning_of_day
      end

      class Weeks
        def to_rrule(rule)
          n = (rule[:weeks_between_triggers] || 1).to_i.clamp(1, 52)
          hour = (rule[:trigger_at_hour] || 0).to_i.clamp(0, 23)
          minute = (rule[:trigger_at_minute] || 0).to_i.clamp(0, 59)
          weekdays = Array.wrap(rule[:trigger_on_weekdays]).map { |d| WEEKDAY_MAP[d.to_i] }.compact
          weekdays = ["SU"] if weekdays.empty?
          "FREQ=WEEKLY;INTERVAL=#{n};BYDAY=#{weekdays.join(",")};BYHOUR=#{hour};BYMINUTE=#{minute}"
        end

        def valid?(rule) = to_rrule(rule).present?

        def matches_now?(rule, dtstart, now)
          ScheduleRule.rrule_matches?(to_rrule(rule), effective_dtstart(dtstart, now), now)
        end

        def effective_dtstart(created, _now) = created.utc.beginning_of_week
      end

      class Months
        def to_rrule(rule)
          n = (rule[:months_between_triggers] || 1).to_i.clamp(1, 12)
          day = (rule[:trigger_at_day_of_month] || 1).to_i.clamp(1, 31)
          hour = (rule[:trigger_at_hour] || 0).to_i.clamp(0, 23)
          minute = (rule[:trigger_at_minute] || 0).to_i.clamp(0, 59)
          "FREQ=MONTHLY;INTERVAL=#{n};BYMONTHDAY=#{day};BYHOUR=#{hour};BYMINUTE=#{minute}"
        end

        def valid?(rule) = to_rrule(rule).present?

        def matches_now?(rule, dtstart, now)
          ScheduleRule.rrule_matches?(to_rrule(rule), effective_dtstart(dtstart, now), now)
        end

        def effective_dtstart(created, _now) = created.utc.beginning_of_month
      end

      class Cron
        def to_rrule(_rule) = nil

        def valid?(rule) = CronParser.valid?(rule.cron)

        def matches_now?(rule, _dtstart, now)
          rule.cron.present? && CronParser.matches?(rule.cron, now)
        end

        def effective_dtstart(created, _now) = created.utc
      end
    end

    INTERVAL_HANDLERS = {
      "seconds" => IntervalHandler::Seconds.new,
      "minutes" => IntervalHandler::Minutes.new,
      "hours" => IntervalHandler::Hours.new,
      "days" => IntervalHandler::Days.new,
      "weeks" => IntervalHandler::Weeks.new,
      "months" => IntervalHandler::Months.new,
      "cron" => IntervalHandler::Cron.new,
    }.freeze

    def wrap(rule)
      rule.is_a?(Rule) ? rule : Rule.new(rule)
    end

    def to_rrule(rule)
      rule = wrap(rule)
      rule.handler.to_rrule(rule)
    end

    def matches_now?(rule, dtstart, now)
      rule = wrap(rule)
      rule.handler.matches_now?(rule, dtstart, now)
    end

    def rules_from_configuration(configuration)
      configuration = wrap(configuration)
      Array.wrap(configuration[:rules])
    end

    def valid_rule?(rule)
      rule = wrap(rule)
      return false if VALID_INTERVALS.exclude?(rule.interval)
      rule.handler.valid?(rule)
    end

    def seconds_rule?(rule)
      wrap(rule).interval == "seconds"
    end

    def seconds_interval(rule)
      (wrap(rule)[:seconds_between_triggers] || 30).to_i.clamp(1, 59)
    end

    def start_seconds_chain!(workflow, node_id, rule_index, rule)
      token = SecureRandom.uuid
      data = workflow.node_static_data(node_id)
      seconds_tokens = data.fetch("seconds_tokens") { {} }
      seconds_tokens[rule_index.to_s] = token
      workflow.update_node_static_data!(node_id, data.merge("seconds_tokens" => seconds_tokens))

      interval = seconds_interval(rule)
      Jobs.enqueue_in(
        interval.seconds,
        Jobs::DiscourseWorkflows::ExecuteSecondsSchedule,
        workflow_id: workflow.id,
        trigger_node_id: node_id,
        rule_index: rule_index,
        token: token,
      )
    end

    def seconds_token_valid?(workflow, node_id, rule_index, token)
      data = workflow.node_static_data(node_id)
      current_token = data.dig("seconds_tokens", rule_index.to_s)
      current_token.present? && current_token == token
    end

    def seconds_needs_watchdog?(workflow, node_id, rule_index, rule, now)
      data = workflow.node_static_data(node_id)
      last_triggered = data.dig("seconds_last_triggered", rule_index.to_s)
      return true if last_triggered.blank?

      interval = seconds_interval(rule)
      elapsed = now - Time.parse(last_triggered)
      elapsed > interval * 3
    end

    def mark_seconds_triggered!(workflow, node_id, rule_index, now)
      data = workflow.node_static_data(node_id)
      seconds_last = data.fetch("seconds_last_triggered") { {} }
      seconds_last[rule_index.to_s] = now.iso8601
      workflow.update_node_static_data!(
        node_id,
        data.merge("seconds_last_triggered" => seconds_last),
      )
    end

    def fire_matching_trigger!(workflow, node, now)
      node_id = node["id"]
      configuration = (node["configuration"] || {}).with_indifferent_access
      rules = rules_from_configuration(configuration)

      rules.each do |rule|
        next if seconds_rule?(rule)
        next unless matches_now?(rule, workflow.created_at, now)

        fired = false
        workflow.with_lock do
          next if TriggerTracking.triggered_this_minute?(workflow, node_id, now)
          TriggerTracking.mark_triggered!(workflow, node_id, now)

          Jobs.enqueue(
            Jobs::DiscourseWorkflows::ExecuteWorkflow,
            workflow_id: workflow.id,
            trigger_node_id: node_id,
            trigger_data: Nodes::Schedule::V1.new.output,
          )
          fired = true
        end

        break if fired
      end
    end

    def restart_stalled_chains!(workflow, node, now)
      node_id = node["id"]
      configuration = (node["configuration"] || {}).with_indifferent_access
      rules = rules_from_configuration(configuration)

      rules.each_with_index do |rule, rule_index|
        next unless seconds_rule?(rule)
        next unless seconds_needs_watchdog?(workflow, node_id, rule_index, rule, now)

        start_seconds_chain!(workflow, node_id, rule_index, rule)
      end
    end

    def rrule_matches?(rrule_str, effective, now)
      return false if rrule_str.blank?

      rrule = RRule::Rule.new(rrule_str, dtstart: effective, tzid: "UTC")
      window_start = now.beginning_of_minute
      window_end = window_start + 59.seconds
      rrule.between(window_start, window_end).any?
    end
  end
end
