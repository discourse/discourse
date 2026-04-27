# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ResumeWebhookWaiting < ::Jobs::Base
      def execute(args)
        return unless SiteSetting.discourse_workflows_enabled

        claimed = ::DiscourseWorkflows::Execution.claim_for_resume(id: args[:execution_id])
        return if claimed.nil?

        response_items = args[:response_items] || [{ "json" => {} }]
        ::DiscourseWorkflows::Executor.resume(claimed, response_items)
      end
    end
  end
end
