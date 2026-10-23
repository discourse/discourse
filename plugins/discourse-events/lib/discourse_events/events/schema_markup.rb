# frozen_string_literal: true

module DiscourseEvents
  module Events
    module SchemaMarkup
      # Generates Schema.org JSON-LD for event topics in regular and crawler HTML.
      #
      # Structure: Event
      #
      # - Only an event attached to the topic's first post is represented
      # - Event times include their configured timezone; all-day events use dates
      # - Descriptions are reduced to plain text suitable for structured data
      #
      # Spec: https://schema.org/Event
      # Validator: https://validator.schema.org/
      def self.build(topic_view)
        return unless SiteSetting.enable_event_schema_for_topics

        topic = topic_view&.topic
        event = topic&.first_post&.event
        return if event.blank? || event.deleted_at.present?

        json_ld_tag(schema(topic, event))
      end

      private_class_method def self.json_ld_tag(schema)
        json = ERB::Util.json_escape(MultiJson.dump(schema)).html_safe
        ApplicationController.helpers.content_tag(:script, json, type: "application/ld+json")
      end

      private_class_method def self.schema(topic, event)
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

      private_class_method def self.description(event)
        return if event.description.blank?

        cooked = Parser.cook_inline(event.description, post: event.post)
        Nokogiri::HTML5.fragment(cooked).text.squish.truncate(250, separator: " ")
      end

      private_class_method def self.serialize_time(time, event)
        return if time.blank?

        zoned_time = time.in_time_zone(event.timezone.presence || Event::DEFAULT_TIMEZONE)
        return zoned_time.to_date.iso8601 if event.all_day

        zoned_time.iso8601(3)
      end
    end
  end
end
