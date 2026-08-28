# frozen_string_literal: true

module DiscourseTopicVoting
  module McpTools
    class SetVote
      def self.call(arguments:, request_context:)
        service =
          (
            if arguments.fetch("voted")
              DiscourseTopicVoting::Votes::Cast
            else
              DiscourseTopicVoting::Votes::Remove
            end
          )
        result =
          service.call(
            params: {
              topic_id: arguments.fetch("topic_id"),
            },
            guardian: request_context.guardian,
          )
        raise DiscourseMcp::ToolError, "Unable to change vote" if result.failure?
        DiscourseMcp::ToolHelpers.text_and_structured(
          topic_id: arguments.fetch("topic_id"),
          voted: arguments.fetch("voted"),
        )
      end
    end
  end
end
