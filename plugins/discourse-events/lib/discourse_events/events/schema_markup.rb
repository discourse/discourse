# frozen_string_literal: true

module DiscourseEvents
  module Events
    class SchemaMarkup
      def self.build(topic_view)
        new(topic_view).build
      end

      def initialize(topic_view)
        @topic_view = topic_view
      end

      def build
        return unless SiteSetting.enable_event_schema_for_topics

        topic = @topic_view&.topic
        event = topic&.first_post&.event
        return if event.blank? || event.deleted_at.present?

        json = MultiJson.dump(schema(topic, event)).gsub("</", "<\\/").html_safe
        "<script type=\"application/ld+json\">#{json}</script>"
      end

      private

      def schema(topic, event)
        {
          "@context" => "https://schema.org",
          "@type" => "Event",
          "name" => event.name.presence || topic.title,
          "description" => description(event),
          "startDate" => serialize_time(event.starts_at, event),
          "endDate" => serialize_time(event.ends_at, event),
          "eventStatus" => "https://schema.org/EventScheduled",
          "url" => topic.url,
        }.compact
      end

      def description(event)
        return if event.description.blank?

        cooked = Parser.cook_inline(event.description, post: event.post)
        Nokogiri::HTML5.fragment(cooked).text.squish.truncate(250, separator: " ")
      end

      def serialize_time(time, event)
        return if time.blank?

        zoned_time = time.in_time_zone(event.timezone.presence || Event::DEFAULT_TIMEZONE)
        return zoned_time.to_date.iso8601 if event.all_day

        zoned_time.iso8601(3)
      end
    end
  end
end
