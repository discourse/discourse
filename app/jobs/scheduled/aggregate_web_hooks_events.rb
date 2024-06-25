# frozen_string_literal: true

module Jobs
  class AggregateWebHooksEvents < ::Jobs::Scheduled
    every 1.day

    def execute(args = {})
      date = args[:date].present? ? args[:date] : Time.zone.now.to_date
      WebHook
        .joins(
          "LEFT JOIN web_hook_events_daily_aggregates ON web_hooks.id = web_hook_events_daily_aggregates.web_hook_id AND web_hook_events_daily_aggregates.date = '#{date}'",
        )
        .where(active: true)
        .where(web_hook_events_daily_aggregates: { id: nil })
        .distinct
        .each do |web_hook|
          WebHookEventsDailyAggregate.create!(web_hook_id: web_hook.id, date: date)
        end
    end
  end
end
