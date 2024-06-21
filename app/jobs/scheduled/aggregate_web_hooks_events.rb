# frozen_string_literal: true

module Jobs
  class AggregateWebHooksEvents < ::Jobs::Scheduled
    every 1.day

    def execute(args = {})
      date = args[:date].present? ? Date.parse(args[:date]) : Time.zone.now.to_date
      WebHook
        .left_joins(:web_hook_events_daily_aggregates)
        .where(active: true)
        .where.not(web_hook_events_daily_aggregates: { date: date })
        .distinct
        .each do |web_hook|
          WebHookEventsDailyAggregate.create!(web_hook_id: web_hook.id, date: date)
        end
    end
  end
end
