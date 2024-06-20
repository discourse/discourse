# frozen_string_literal: true

module Jobs
  class AggregateWebHooksEvents < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      WebHook.all.each do |web_hook|
        WebHookEventsDailyAggregate.create!(web_hook_id: web_hook.id, date: Time.zone.now.to_date)
      end
    end
  end
end
