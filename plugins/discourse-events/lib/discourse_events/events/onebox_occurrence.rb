# frozen_string_literal: true

require "rrule"

module DiscourseEvents
  module Events
    # Cooked event oneboxes keep whichever occurrence was next when they were fetched.
    # This finds the occurrence that's current now from the Schema.org schedule they
    # carry, so posts and emails don't show a date that has already passed.
    class OneboxOccurrence
      WORKWEEK = %w[Monday Tuesday Wednesday Thursday Friday]
      WEEKLY_INTERVALS = { "P1W" => 1, "P2W" => 2, "P4W" => 4 }
      MONTH_WEEKS = %w[1 2 3 4 -1]

      # The longest gap between occurrences, for monthly events, is five weeks
      MAX_GAP = 5.weeks

      # Returns { onebox source URL => { starts_at:, ends_at: } } for oneboxes that have moved on
      def self.for_cooked(cooked)
        return {} if !cooked&.include?("discourse-event-onebox")

        Nokogiri::HTML5
          .fragment(cooked)
          .css(".discourse-event-onebox")
          .each_with_object({}) do |node, occurrences|
            src = node.ancestors("aside.onebox").first&.[]("data-onebox-src")
            occurrence = new(node).current if src.present?
            occurrences[src] = occurrence if occurrence
          end
      end

      def initialize(node, now: Time.current)
        @node = node
        @now = now
      end

      def current
        return if (rule = rrule).blank?

        # The earliest start whose occurrence hasn't finished yet
        earliest = @now - duration - (all_day? ? 1.day : 0) + 1.second

        # `between` rather than `from`, which returns nothing for rules with an interval
        upcoming = rule.between(earliest, earliest + MAX_GAP).first || final_occurrence(rule)
        return if upcoming.nil? || upcoming <= starts_at

        { starts_at: serialize(upcoming), ends_at: (serialize(upcoming + duration) if ends_at) }
      rescue ArgumentError, ::RRule::InvalidRRule
        nil
      end

      def apply!
        return if (occurrence = current).nil?

        starts_at = parse_time(occurrence[:starts_at])

        @node["data-event-starts-at"] = occurrence[:starts_at]
        @node["data-event-ends-at"] = occurrence[:ends_at].to_s
        @node.at_css(".discourse-event-onebox__date")&.[]=("datetime", occurrence[:starts_at])
        @node.at_css(".discourse-event-onebox__month")&.content = starts_at.strftime("%b")
        @node.at_css(".discourse-event-onebox__day")&.content = starts_at.strftime("%-d")

        if !all_day?
          ends_at = parse_time(occurrence[:ends_at]) if occurrence[:ends_at]
          @node.at_css(".discourse-event-onebox__time-text")&.content =
            Onebox::Engine::DiscourseTopicOnebox.format_event_time(starts_at, ends_at)
        end
      end

      private

      def rrule
        pattern = rrule_pattern
        return if pattern.blank?

        if (until_date = repeat_until)
          finishes = timezone.parse(until_date.iso8601).end_of_day
          pattern += ";UNTIL=#{finishes.strftime("%Y%m%dT%H%M%S")}"
        end

        ::RRule::Rule.new(pattern, dtstart: starts_at, tzid: timezone.tzinfo.name)
      end

      def rrule_pattern
        weekday = rrule_day(by_day.first) || starts_at.strftime("%a").upcase[0, 2]

        case @node["data-event-repeat-frequency"]
        when "P1D"
          if by_day.empty?
            "FREQ=DAILY"
          elsif by_day.sort == WORKWEEK.sort
            "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR"
          end
        when *WEEKLY_INTERVALS.keys
          interval = WEEKLY_INTERVALS[@node["data-event-repeat-frequency"]]
          "FREQ=WEEKLY;INTERVAL=#{interval};BYDAY=#{weekday}"
        when "P1M"
          month_week = @node["data-event-repeat-by-month-week"]
          "FREQ=MONTHLY;BYDAY=#{month_week}#{weekday}" if MONTH_WEEKS.include?(month_week)
        end
      end

      def final_occurrence(rule)
        return if (until_date = repeat_until).nil?

        finishes = timezone.parse(until_date.iso8601).end_of_day
        rule.between(finishes - MAX_GAP, finishes).last
      end

      def by_day
        @by_day ||= @node["data-event-repeat-by-day"].to_s.split(",")
      end

      def rrule_day(name)
        name.upcase[0, 2] if Date::DAYNAMES.include?(name)
      end

      def repeat_until
        value = @node["data-event-repeat-until"]
        Date.iso8601(value) if value.present?
      rescue Date::Error
        nil
      end

      def all_day?
        @node["data-event-all-day"] == "true"
      end

      # Stepping in the event's own timezone keeps its wall-clock time across DST changes
      def timezone
        @timezone ||=
          (!all_day? && ActiveSupport::TimeZone[@node["data-event-schedule-timezone"].to_s]) ||
            ActiveSupport::TimeZone["UTC"]
      end

      def starts_at
        @starts_at ||= parse_time(@node["data-event-starts-at"])
      end

      def ends_at
        return @ends_at if defined?(@ends_at)

        value = @node["data-event-ends-at"]
        @ends_at = (parse_time(value) if value.present?)
      end

      def duration
        ends_at ? ends_at - starts_at : 0
      end

      def parse_time(value)
        if all_day?
          timezone.parse(Date.iso8601(value).iso8601)
        else
          Time.iso8601(value).in_time_zone(timezone)
        end
      end

      def serialize(time)
        all_day? ? time.strftime("%Y-%m-%d") : time.iso8601(3)
      end
    end
  end
end
