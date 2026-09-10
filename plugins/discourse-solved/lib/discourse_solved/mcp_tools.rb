# frozen_string_literal: true

module DiscourseSolved
  module McpTools
    class SetSolution
      def self.call(arguments:, request_context:)
        service =
          (
            if arguments.fetch("accepted")
              DiscourseSolved::AcceptAnswer
            else
              DiscourseSolved::UnacceptAnswer
            end
          )
        result =
          service.call(
            params: {
              post_id: arguments.fetch("post_id"),
            },
            guardian: request_context.guardian,
          )
        raise DiscourseMcp::ToolError, "Unable to change solution" if result.failure?
        DiscourseMcp::ToolHelpers.text_and_structured(
          post_id: arguments.fetch("post_id"),
          accepted: arguments.fetch("accepted"),
        )
      end
    end
  end
end
