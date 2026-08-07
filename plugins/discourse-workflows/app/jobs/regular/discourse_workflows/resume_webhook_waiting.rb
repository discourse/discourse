# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ResumeWebhookWaiting < ::Jobs::Base
      def execute(args)
        return unless SiteSetting.enable_discourse_workflows

        execution =
          ::DiscourseWorkflows::Execution.find_by(id: args[:execution_id], status: :waiting)
        return if execution.nil?

        claimed = ::DiscourseWorkflows::Execution.claim_for_resume(execution)
        return if claimed.nil?

        response_items = args[:response_items] || [{ "json" => {} }]
        ::DiscourseWorkflows::Executor.resume(claimed, response_items)
      end
    end
  end
end
