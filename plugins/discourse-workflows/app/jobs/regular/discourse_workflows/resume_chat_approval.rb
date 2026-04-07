# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ResumeChatApproval < ::Jobs::Base
      def execute(args)
        ::DiscourseWorkflows::ChatApproval::Resume.call(
          params: {
            execution_id: args[:execution_id],
            approved: args[:approved],
          },
        )
      end
    end
  end
end
