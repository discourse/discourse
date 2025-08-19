# frozen_string_literal: true

module DiscoursePostEvent
  class BasicEventSerializer < ApplicationSerializer
    attributes :id
    attributes :category_id
    attributes :name
    attributes :recurrence
    attributes :recurrence_until
    attributes :starts_at
    attributes :ends_at
    attributes :rrule
    attributes :show_local_time
    attributes :timezone
    attributes :post

    def category_id
      object.post.topic.category_id
    end

    def post
      {
        id: object.post.id,
        post_number: object.post.post_number,
        url: object.post.url,
        topic: {
          id: object.post.topic.id,
          title: object.post.topic.title,
        },
      }
    end

    def include_rrule?
      object.recurring?
    end

    def rrule
      return nil unless include_rrule?

      # Use UTC for RRULE to avoid timezone compatibility issues with FullCalendar
      RRuleGenerator.generate_string(
        starts_at: object.original_starts_at,
        timezone: "UTC",
        recurrence: object.recurrence,
        recurrence_until: object.recurrence_until,
        dtstart: object.original_starts_at,
      )
    end

    def starts_at
      # For recurring events, use UTC to match RRULE
      # For non-recurring events, use the event's timezone
      if object.recurring?
        object.original_starts_at
      else
        object.starts_at.in_time_zone(object.timezone)
      end
    end

    def ends_at
      if object.ends_at
        if object.recurring?
          object.ends_at
        else
          object.ends_at.in_time_zone(object.timezone)
        end
      else
        # Use consistent timezone as starts_at for calculation
        base_starts_at =
          (
            if object.recurring?
              object.original_starts_at
            else
              object.starts_at.in_time_zone(object.timezone)
            end
          )
        (base_starts_at + 1.hour)
      end
    end

    def timezone
      # For events with RRULE, return UTC since we're sending UTC times
      if include_rrule?
        "UTC"
      else
        object.timezone
      end
    end
  end
end
