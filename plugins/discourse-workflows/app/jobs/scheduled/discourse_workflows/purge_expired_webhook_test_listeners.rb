# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class PurgeExpiredWebhookTestListeners < ::Jobs::Scheduled
      every 5.minutes

      def execute(_args = nil)
        ::DiscourseWorkflows::WebhookTestListener.purge_expired!
      end
    end
  end
end
