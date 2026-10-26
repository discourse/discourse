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
      # - Events without a location or URL are skipped, since search engines require a location
      # - Descriptions are reduced to plain text suitable for structured data
      # - The event's own image is included so link previews don't fall back to the topic's
      #
      # Spec: https://schema.org/Event
      # Validator: https://validator.schema.org/
      def self.build(topic_view)
        return unless SiteSetting.enable_event_schema_for_topics
        return unless SiteSetting.discourse_post_event_enabled

        topic = topic_view&.topic
        event = first_post(topic_view)&.event
        return if event.blank? || event.deleted_at.present?

        locations = locations(event)
        return if locations.empty?

        json_ld_tag(schema(topic, event, locations))
      end

      # Topic views have usually loaded the first post with its event already, so this runs on
      # every topic page without extra queries
      private_class_method def self.first_post(topic_view)
        topic_view.posts&.find { |post| post.post_number == 1 } || topic_view.topic&.first_post
      end

      private_class_method def self.json_ld_tag(schema)
        json = ERB::Util.json_escape(MultiJson.dump(schema)).html_safe
        ApplicationController.helpers.content_tag(:script, json, type: "application/ld+json")
      end

      private_class_method def self.schema(topic, event, locations)
        {
          "@context" => "https://schema.org",
          "@type" => "Event",
          "name" => event.name.presence || topic.title,
          "description" => description(event),
          "startDate" => serialize_time(event.starts_at, event),
          "endDate" => serialize_time(event.ends_at, event),
          "eventStatus" => "https://schema.org/EventScheduled",
          "eventAttendanceMode" => attendance_mode(locations),
          "location" => locations.one? ? locations.first : locations,
          "url" => topic.url,
          "image" => image(topic, event),
        }.compact
      end

      private_class_method def self.locations(event)
        locations = []

        place = plain_text(event.location, event)

        # A location that's only a link is where the event streams, not a place
        if web_url?(place)
          locations << { "@type" => "VirtualLocation", "url" => place }
        elsif place.present?
          locations << { "@type" => "Place", "name" => place, "address" => place }
        end

        if web_url?(event.url) && locations.none? { |location| location["url"] == event.url }
          locations << { "@type" => "VirtualLocation", "url" => event.url }
        end

        locations
      end

      private_class_method def self.web_url?(value)
        value.present? && value.match?(%r{\Ahttps?://\S+\z}i)
      end

      private_class_method def self.attendance_mode(locations)
        types = locations.map { |location| location["@type"] }

        mode =
          if types.include?("Place") && types.include?("VirtualLocation")
            "Mixed"
          elsif types.include?("Place")
            "Offline"
          else
            "Online"
          end

        "https://schema.org/#{mode}EventAttendanceMode"
      end

      private_class_method def self.image(topic, event)
        upload = event.image_upload
        return if upload.blank? || upload.secure?

        # The topic image is synced from the event image and has a share-sized thumbnail
        url =
          if topic.image_upload_id == upload.id
            topic.image_url
          else
            UrlHelper.cook_url(upload.url, local: true)
          end
        return if url.blank?

        {
          "@type" => "ImageObject",
          "url" => ApplicationController.helpers.get_absolute_image_url(url),
          "width" => upload.width,
          "height" => upload.height,
        }.compact
      end

      private_class_method def self.description(event)
        plain_text(event.description, event)&.truncate(250, separator: " ")
      end

      private_class_method def self.plain_text(value, event)
        return if value.blank?

        cooked = Parser.cook_inline(value, post: event.post)
        Nokogiri::HTML5.fragment(cooked).text.squish.presence
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
