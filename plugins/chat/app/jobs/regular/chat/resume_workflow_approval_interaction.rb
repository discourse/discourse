# frozen_string_literal: true

module Jobs
  module Chat
    class ResumeWorkflowApprovalInteraction < ::Jobs::Base
      def execute(args)
        ::Chat::Workflows::Approval::ResumeInteraction.call(
          params: {
            interaction_id: args[:interaction_id],
          },
        )
      end
    end
  end
end
