# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ResumeWebhookWaiting < ::Jobs::Base
      def execute(args)
        return unless SiteSetting.discourse_workflows_enabled

        execution =
          ::DiscourseWorkflows::Execution
            .where(id: args[:execution_id], status: :waiting)
            .lock("FOR UPDATE SKIP LOCKED")
            .first
        return if execution.nil?

        response_items = args[:response_items] || [{ "json" => {} }]
        ::DiscourseWorkflows::Executor.resume(execution, response_items)
      end
    end
  end
end
