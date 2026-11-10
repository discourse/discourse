# frozen_string_literal: true

# Generates Schema.org JSON-LD for an event topic.
#
# Structure: Event
#
# - Event times include their configured timezone; all-day events use dates
# - Events without a location or URL use the topic URL as their virtual location
# - Descriptions are reduced to plain text suitable for structured data
# - The event's own image is included so link previews don't fall back to the topic's
# - Recurring events describe their pattern with a Schedule, anchored on the current occurrence
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
      "eventSchedule" => schedule,
    }.compact
  end

  def schedule
    return if !event.recurring?

    # The recurrence rule is anchored on the original start, which sets the week of the month
    original_starts_at =
      if event.all_day
        event.original_starts_at.utc
      else
        event.original_starts_at.in_time_zone(event.rrule_timezone)
      end
    weekday = "https://schema.org/#{original_starts_at.strftime("%A")}"

    {
      "@type" => "Schedule",
      **schedule_pattern(original_starts_at, weekday),
      "endDate" => event.recurrence_until&.in_time_zone(event.rrule_timezone)&.strftime("%Y-%m-%d"),
      "scheduleTimezone" => (event.rrule_timezone if !event.all_day),
    }.compact
  end

  def schedule_pattern(starts_at, weekday)
    case event.recurrence
    when "every_day"
      { "repeatFrequency" => "P1D" }
    when "every_weekday"
      {
        "repeatFrequency" => "P1D",
        "byDay" => %w[Monday Tuesday Wednesday Thursday Friday].map { "https://schema.org/#{it}" },
      }
    when "every_two_weeks"
      { "repeatFrequency" => "P2W", "byDay" => weekday }
    when "every_four_weeks"
      { "repeatFrequency" => "P4W", "byDay" => weekday }
    when "every_month"
      # Mirrors the recurrence rule, where a fifth weekday is expressed as the last
      nth = ((starts_at.day - 1) / 7) + 1
      { "repeatFrequency" => "P1M", "byDay" => weekday, "byMonthWeek" => nth == 5 ? -1 : nth }
    else
      { "repeatFrequency" => "P1W", "byDay" => weekday }
    end
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
