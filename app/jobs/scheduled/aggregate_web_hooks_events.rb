# frozen_string_literal: true

module Jobs
  class AggregateWebHooksEvents < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      today_web_hooks_events =
        WebHookEvent.where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day)
      today_web_hooks_events.each do |web_hooks_event|
        WebHookEventsDailyAggregate.create!(
          web_hook_id: web_hooks_event.web_hook_id,
          date: Time.zone.now.beginning_of_day.to_date,
        )
      end
    end
  end
end
