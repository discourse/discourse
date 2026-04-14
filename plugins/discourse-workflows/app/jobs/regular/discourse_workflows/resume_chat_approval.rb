# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ResumeChatApproval < ::Jobs::Base
      def execute(args)
        ::DiscourseWorkflows::ChatApproval::Resume.call(
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
