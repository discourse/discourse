# frozen_string_literal: true

module DiscourseAutomation
  module Triggers
    module Recurring
      RECURRENCE_CHOICES = [
        { id: "minute", name: "discourse_automation.triggerables.recurring.frequencies.minute" },
        { id: "hour", name: "discourse_automation.triggerables.recurring.frequencies.hour" },
        { id: "day", name: "discourse_automation.triggerables.recurring.frequencies.day" },
        { id: "weekday", name: "discourse_automation.triggerables.recurring.frequencies.weekday" },
        { id: "week", name: "discourse_automation.triggerables.recurring.frequencies.week" },
        { id: "month", name: "discourse_automation.triggerables.recurring.frequencies.month" },
        { id: "year", name: "discourse_automation.triggerables.recurring.frequencies.year" },
      ].freeze

      def self.setup_pending_automation(automation, fields, previous_fields)
        start_date = fields.dig("start_date", "value")
        interval = fields.dig("recurrence", "value", "interval")
        frequency = fields.dig("recurrence", "value", "frequency")

        # this case is not possible in practice but better be safe
        if !start_date || !interval || !frequency
          automation.pending_automations.destroy_all
          return
        end

        previous_start_date = previous_fields&.dig("start_date", "value")
        previous_interval = previous_fields&.dig("recurrence", "value", "interval")
        previous_frequency = previous_fields&.dig("recurrence", "value", "frequency")

        if previous_start_date != start_date || previous_interval != interval ||
             previous_frequency != frequency
          automation.pending_automations.destroy_all
        elsif automation.pending_automations.present?
          log_debugging_info(
            id: automation.id,
            start_date:,
            interval:,
            frequency:,
            previous_start_date:,
            previous_interval:,
            previous_frequency:,
            now: Time.zone.now,
          )
          return
        end

        start_date = Time.parse(start_date)
        if start_date > Time.zone.now
          automation.pending_automations.create!(execute_at: start_date)
          return
        end

        byday = start_date.strftime("%A").upcase[0, 2]
        interval = interval.to_i
        interval_end = interval + 1

        next_trigger_date =
          case frequency
          when "minute"
            (Time.zone.now + interval.minute).beginning_of_minute
          when "hour"
            (Time.zone.now + interval.hour).beginning_of_hour
          when "day"
            RRule::Rule
              .new("FREQ=DAILY;INTERVAL=#{interval}", dtstart: start_date)
              .between(Time.now, interval_end.days.from_now)
              .find { |date| date > Time.zone.now }
          when "weekday"
            max_weekends = (interval_end.to_f / 5).ceil
            RRule::Rule
              .new("FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR", dtstart: start_date)
              .between(Time.now.end_of_day, max_weekends.weeks.from_now)
              .drop(interval - 1)
              .find { |date| date > Time.zone.now }
          when "week"
            RRule::Rule
              .new("FREQ=WEEKLY;INTERVAL=#{interval};BYDAY=#{byday}", dtstart: start_date)
              .between(Time.now.end_of_week, interval_end.weeks.from_now)
              .find { |date| date > Time.zone.now }
          when "month"
            count = 0
            (start_date.beginning_of_month.to_date..start_date.end_of_month.to_date).each do |date|
              count += 1 if date.strftime("%A") == start_date.strftime("%A")
              break if date.day == start_date.day
            end
            RRule::Rule
              .new("FREQ=MONTHLY;INTERVAL=#{interval};BYDAY=#{count}#{byday}", dtstart: start_date)
              .between(Time.now, interval_end.months.from_now)
              .find { |date| date > Time.zone.now }
          when "year"
            RRule::Rule
              .new("FREQ=YEARLY;INTERVAL=#{interval}", dtstart: start_date)
              .between(Time.now, interval_end.years.from_now)
              .find { |date| date > Time.zone.now }
          end

        if next_trigger_date
          automation.pending_automations.create!(execute_at: next_trigger_date)
        else
          log_debugging_info(
            id: automation.id,
            start_date:,
            interval:,
            frequency:,
            previous_start_date:,
            previous_interval:,
            previous_frequency:,
            byday:,
            interval_end:,
            next_trigger_date:,
            now: Time.zone.now,
          )
          nil
        end
      end

      def self.log_debugging_info(context)
        return if !SiteSetting.discourse_automation_enable_recurring_debug
        str = "[automation] scheduling recurring automation debug: "
        str += context.map { |k, v| "#{k}=#{v.inspect}" }.join(", ")
        Rails.logger.warn(str)
      end
    end
  end
end

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggers::RECURRING) do
  field :recurrence,
        component: :period,
        extra: {
          content: DiscourseAutomation::Triggers::Recurring::RECURRENCE_CHOICES,
        },
        required: true
  field :start_date, component: :date_time, required: true

  on_update do |automation, fields, previous_fields|
    DiscourseAutomation::Triggers::Recurring.setup_pending_automation(
      automation,
      fields,
      previous_fields,
    )
  end
  on_call do |automation, fields, previous_fields|
    DiscourseAutomation::Triggers::Recurring.setup_pending_automation(
      automation,
      fields,
      previous_fields,
    )
  end

  enable_manual_trigger
end
