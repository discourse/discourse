# frozen_string_literal: true

module DiscourseEvents
  module Events
    # Replaces each event node in an excerpt fragment (see PrettyText.excerpt)
    # with a short plain-text summary — "📅 name · dates · location"
    class Excerpt
      def self.call(fragment, post: nil)
        new(fragment, post: post).call
      end

      # +starts_at+ and +ends_at+ must already be in the event's wall-clock
      # time; +timezone+ is only used as a label
      def self.format_dates(starts_at, ends_at, all_day:, timezone:)
        ends_at = nil if all_day && same_day?(starts_at, ends_at)

        dates = format_date(starts_at, all_day)
        dates = t("date_range", from: dates, to: format_date(ends_at, all_day)) if ends_at.present?
        dates = t("date_with_timezone", date: dates, timezone: timezone) unless all_day
        dates
      end

      def self.format_date(value, all_day)
        I18n.l(value, format: t(all_day ? "date_format" : "datetime_format"))
      rescue I18n::ArgumentError
        value.to_s
      end

      def self.same_day?(starts_at, ends_at)
        [starts_at, ends_at].all? { |date| date.is_a?(Date) || date.is_a?(Time) } &&
          starts_at.to_date == ends_at.to_date
      end

      def self.t(key, **args)
        I18n.t("discourse_post_event.event_excerpt.#{key}", **args)
      end

      private_class_method :format_date, :same_day?

      def initialize(fragment, post: nil)
        @fragment = fragment
        @topic_title = post&.topic&.title
      end

      def call
        @fragment
          .css(".discourse-post-event")
          .each { |event_node| event_node.replace(CGI.escape_html(summary(event_node))) }
      end

      private

      def summary(event_node)
        event_name = event_node["data-name"].presence
        location = event_node["data-location"].presence
        location = Parser.inline_text(location) if location

        parts = []
        # only repeat the name when it differs from the topic title, which is
        # already shown alongside the excerpt (e.g. in the topic onebox)
        parts << event_name if event_name && event_name != @topic_title
        parts << dates(event_node)
        parts << location

        summary = parts.compact.join(self.class.t("separator"))
        summary.present? ? self.class.t("summary", summary: summary) : ""
      end

      def dates(event_node)
        starts_at = event_node["data-start"]
        return if starts_at.blank?

        self.class.format_dates(
          parse_date(starts_at),
          parse_date(event_node["data-end"]),
          all_day: event_node["data-all-day"] == "true",
          timezone: event_node["data-timezone"] || "UTC",
        )
      end

      # unparseable values are kept as-is so the summary still shows something
      def parse_date(value)
        return if value.blank?
        DateTime.parse(value)
      rescue ArgumentError
        value
      end
    end
  end
end
