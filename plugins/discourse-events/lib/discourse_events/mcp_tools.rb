# frozen_string_literal: true

module DiscourseEvents
  module McpTools
    class ListEvents
      OUTPUT_SCHEMA =
        DiscourseMcp::OutputSchema.object(
          events: {
            type: "array",
            items:
              DiscourseMcp::OutputSchema.object(
                id: DiscourseMcp::OutputSchema::INTEGER,
                post_id: DiscourseMcp::OutputSchema::INTEGER,
                topic_id: DiscourseMcp::OutputSchema::INTEGER,
                name: DiscourseMcp::OutputSchema::STRING,
                starts_at: DiscourseMcp::OutputSchema::STRING_OR_NULL,
                ends_at: DiscourseMcp::OutputSchema::STRING_OR_NULL,
                status: DiscourseMcp::OutputSchema::ANY,
              ),
          },
        )

      def self.call(arguments:, request_context:)
        limit = arguments.fetch("limit", 50).to_i.clamp(1, 100)
        events =
          DiscourseEvents::Events::Finder.search(
            request_context.user,
            after: "now",
            include_ongoing: true,
            limit:,
          ).preload(post: :topic)
        values =
          events.map do |event|
            {
              id: event.id,
              post_id: event.post.id,
              topic_id: event.post.topic_id,
              name: event.name,
              starts_at: event.starts_at&.iso8601,
              ends_at: event.ends_at&.iso8601,
              status: event.status,
            }
          end
        DiscourseMcp::ToolHelpers.text_and_structured(events: values)
      end
    end
  end
end
