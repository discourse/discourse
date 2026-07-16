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

      summary = parts.compact.join(" · ")
      summary.present? ? "📅 #{summary}" : ""
    end

    def dates(event_node)
      starts_at = event_node["data-start"]
      return if starts_at.blank?

      all_day = event_node["data-all-day"] == "true"
      ends_at = event_node["data-end"]
      timezone = event_node["data-timezone"] || "UTC"

      dates = format_date(starts_at, all_day)
      dates = "#{dates} → #{format_date(ends_at, all_day)}" if ends_at.present?
      dates = "#{dates} (#{timezone})" unless all_day
      dates
    end

    def format_date(value, all_day)
      DateTime.parse(value).strftime(all_day ? "%B %-d, %Y" : "%B %-d, %Y %-I:%M %p")
    rescue StandardError
      value
    end
  end
end
