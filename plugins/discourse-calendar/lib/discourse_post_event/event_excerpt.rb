# frozen_string_literal: true

module DiscoursePostEvent
  # Replaces each event node in an excerpt fragment (see PrettyText.excerpt)
  # with a short plain-text summary — "📅 name · dates · location"
  class EventExcerpt
    def self.call(fragment, post: nil)
      new(fragment, post: post).call
    end

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

      parts = []
      # only repeat the name when it differs from the topic title, which is
      # already shown alongside the excerpt (e.g. in the topic onebox)
      parts << event_name if event_name && event_name != @topic_title
      parts << dates(event_node)
      parts << location

      summary = parts.compact.join(t("separator"))
      summary.present? ? t("summary", summary: summary) : ""
    end

    def dates(event_node)
      starts_at = event_node["data-start"]
      return if starts_at.blank?

      all_day = event_node["data-all-day"] == "true"
      ends_at = event_node["data-end"]
      timezone = event_node["data-timezone"] || "UTC"

      dates = format_date(starts_at, all_day)
      dates = t("date_range", from: dates, to: format_date(ends_at, all_day)) if ends_at.present?
      dates = t("date_with_timezone", date: dates, timezone: timezone) unless all_day
      dates
    end

    def format_date(value, all_day)
      I18n.l(DateTime.parse(value), format: t(all_day ? "date_format" : "datetime_format"))
    rescue StandardError
      value
    end

    def t(key, **args)
      I18n.t("discourse_post_event.event_excerpt.#{key}", **args)
    end
  end
end
