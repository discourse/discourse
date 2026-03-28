# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ResumeWebhookWaiting < ::Jobs::Base
      def execute(args)
        execution = ::DiscourseWorkflows::Execution.find_by(id: args[:execution_id])
        return if execution.nil?
        return unless execution.waiting?

        response_items = args[:response_items] || [{ "json" => {} }]
        ::DiscourseWorkflows::Executor.resume(execution, response_items)
      end
    end
  end
end
