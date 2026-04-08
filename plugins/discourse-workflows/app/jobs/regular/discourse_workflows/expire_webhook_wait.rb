# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ExpireWebhookWait < ::Jobs::Base
      def execute(args)
        execution =
          ::DiscourseWorkflows::Execution
            .includes(:execution_data)
            .where(id: args[:execution_id], status: :waiting)
            .lock("FOR UPDATE SKIP LOCKED")
            .first
        return if execution.nil?
        unless ::DiscourseWorkflows::Executor::WaitHandlers::Webhook.handles_execution?(execution)
          return
        end

        ::DiscourseWorkflows::Executor::WaitHandlers::Webhook.on_timeout(execution)
      end
    end
  end
end
