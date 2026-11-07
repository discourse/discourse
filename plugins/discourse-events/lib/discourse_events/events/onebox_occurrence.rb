# frozen_string_literal: true

require "rrule"

module DiscourseEvents
  module Events
    # Cooked event oneboxes keep whichever occurrence was next when they were fetched.
    # This finds the occurrence that's current now from the recurrence rule they carry,
    # so posts and emails don't show a date that has already passed.
    class OneboxOccurrence
      # The longest gap between occurrences, for monthly events, is five weeks
      MAX_GAP = 5.weeks

      # Only the rules the topic onebox writes, as others (e.g. with COUNT) can't skip ahead safely
      DAY = "(SU|MO|TU|WE|TH|FR|SA)"
      SUPPORTED_RRULE =
        /\AFREQ=(DAILY(;BYDAY=MO,TU,WE,TH,FR)?|WEEKLY;INTERVAL=[124];BYDAY=#{DAY}|MONTHLY;BYDAY=(-1|[1-4])#{DAY})(;UNTIL=\d{8}T\d{6})?\z/

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
        return if !SUPPORTED_RRULE.match?(@node["data-event-rrule"].to_s)

        # The earliest start whose occurrence hasn't finished yet
        earliest = @now - duration - (all_day? ? 1.day : 0) + 1.second

        finishes = repeat_until
        rule = rrule(anchor: finishes ? [earliest, finishes - MAX_GAP].min : earliest)

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

      # Rules with an interval are stepped through from their start, which is untrusted and can be
      # ages ago, so it's moved up to just before `anchor` by whole periods, keeping the same series.
      # One period is held back so a DST change can't push the start past `anchor`.
      def rrule(anchor:)
        pattern = @node["data-event-rrule"]
        period = [pattern[/INTERVAL=(\d)/, 1].to_i, 1].max.weeks
        periods = [((anchor - starts_at) / period.to_i).floor - 1, 0].max

        ::RRule::Rule.new(
          pattern,
          dtstart: starts_at + (periods * period),
          tzid: timezone.tzinfo.name,
        )
      end

      def final_occurrence(rule)
        return if (finishes = repeat_until).nil?

        rule.between(finishes - MAX_GAP, finishes).last
      end

      def repeat_until
        value = @node["data-event-rrule"].to_s[/UNTIL=(\d{8}T\d{6})/, 1]
        timezone.strptime(value, "%Y%m%dT%H%M%S") if value
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
