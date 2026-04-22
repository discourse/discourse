# frozen_string_literal: true

module Jobs
  module Chat
    class ResumeWorkflowApproval < ::Jobs::Base
      def execute(args)
        ::Chat::Workflows::ApprovalResume.call(
          params: {
            execution_id: args[:execution_id],
            approved: args[:approved],
            action_token: args[:action_token],
          },
        )
      end
    end
  end
end
