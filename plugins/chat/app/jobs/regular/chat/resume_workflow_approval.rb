# frozen_string_literal: true

module Jobs
  module Chat
    class ResumeWorkflowApproval < ::Jobs::Base
      def execute(args)
        ::Chat::Workflows::Approval::Resume.call(
          params: {
            action_id: args[:action_id],
            channel_id: args[:channel_id],
          },
        )
      end
    end
  end
end
