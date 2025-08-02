# frozen_string_literal: true

module Jobs
  class CleanupRedeliveringWebHookEvents < ::Jobs::Scheduled
    every 1.hour

    sidekiq_options queue: "low"

    def execute(args)
      RedeliveringWebhookEvent
        .includes(web_hook_event: :web_hook)
        .where("created_at < ?", 8.hour.ago)
        .delete_all
    end
  end
end
