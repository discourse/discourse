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
      RRuleGenerator.generate_string(
        starts_at: object.starts_at.in_time_zone(object.timezone),
        timezone: object.timezone,
        recurrence: object.recurrence,
        recurrence_until: object.recurrence_until&.in_time_zone(object.timezone),
        dtstart: object.starts_at.in_time_zone(object.timezone),
      )
    end

    def ends_at
      object.ends_at || object.starts_at + 1.hour
    end
  end
end
