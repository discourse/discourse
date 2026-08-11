# frozen_string_literal: true

module DiscourseCalendar
  module McpTools
    class ListEvents
      def self.call(arguments:, principal:)
        limit = arguments.fetch("limit", 50).to_i.clamp(1, 100)
        events =
          DiscoursePostEvent::Event
            .visible
            .includes(post: :topic)
            .order(starts_at: :asc)
            .limit(limit * 3)
        values =
          events
            .filter_map do |event|
              next if event.post.blank? || !principal.guardian.can_see?(event.post)
              {
                id: event.id,
                post_id: event.post_id,
                topic_id: event.post.topic_id,
                name: event.name,
                starts_at: event.starts_at&.iso8601,
                ends_at: event.ends_at&.iso8601,
                status: event.status,
              }
            end
            .first(limit)
        DiscourseMcp::ToolHelpers.text_and_structured(events: values)
      end
    end
  end
end
