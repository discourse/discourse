# frozen_string_literal: true

module Jobs
  class AggregateWebHooksEvents < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      today_web_hooks_ids =
        WebHookEvent
          .where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day)
          .uniq(&:web_hook_id)
          .pluck(:web_hook_id)

      today_web_hooks_ids.each do |web_hook_id|
        WebHookEventsDailyAggregate.create!(web_hook_id: web_hook_id, date: Time.zone.now.to_date)
      end
    end
  end
end
