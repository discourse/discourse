# frozen_string_literal: true

# Generates Schema.org JSON-LD for an event topic.
#
# Structure: Event
#
# - Event times include their configured timezone; all-day events use dates
# - Events without a location or URL use the topic URL as their virtual location
# - Descriptions are reduced to plain text suitable for structured data
# - The event's own image is included so link previews don't fall back to the topic's
#
# Spec: https://schema.org/Event
# Validator: https://validator.schema.org/
class DiscourseEvents::Events::Action::GenerateSchemaJson < Service::ActionBase
  option :event
  option :first_post
  option :topic

  def call
    MultiJson.dump(schema)
  end

  private

  def schema
    event_locations = locations

    {
      "@context" => "https://schema.org",
      "@type" => "Event",
      "name" => event.name.presence || topic.title,
      "description" => description,
      "startDate" => serialize_time(event.starts_at),
      "endDate" => serialize_time(event.ends_at),
      "eventStatus" => "https://schema.org/EventScheduled",
      "eventAttendanceMode" => attendance_mode(event_locations),
      "location" => event_locations.one? ? event_locations.first : event_locations,
      "url" => topic.url,
      "image" => image,
    }.compact
  end

  def locations
    event_locations = []
    place = plain_text(event.location)

    # A location that's only a link is where the event streams, not a place
    if place&.match?(%r{\Ahttps?://\S+\z}i)
      event_locations << { "@type" => "VirtualLocation", "url" => place }
    elsif place.present?
      event_locations << { "@type" => "Place", "name" => place, "address" => place }
    end

    if event.url&.match?(%r{\Ahttps?://\S+\z}i) &&
         event_locations.none? { |location| location["url"] == event.url }
      event_locations << { "@type" => "VirtualLocation", "url" => event.url }
    end

    if event_locations.empty?
      event_locations << { "@type" => "VirtualLocation", "url" => topic.url }
    end

    event_locations
  end

  def attendance_mode(event_locations)
    types = event_locations.map { |location| location["@type"] }

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

  def image
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

  def description
    plain_text(event.description)&.truncate(250, separator: " ")
  end

  def plain_text(value)
    return if value.blank?

    cooked = DiscourseEvents::Events::Parser.cook_inline(value, post: first_post)
    Nokogiri::HTML5.fragment(cooked).text.squish.presence
  end

  def serialize_time(time)
    return if time.blank?
    return time.utc.strftime("%Y-%m-%d") if event.all_day

    zoned_time =
      time.in_time_zone(event.timezone.presence || DiscourseEvents::Events::Event::DEFAULT_TIMEZONE)
    zoned_time.iso8601(3)
  end
end
