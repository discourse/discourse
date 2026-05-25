# frozen_string_literal: true

module Jobs
  class AggregateBrowserPageviewDailyRollups < ::Jobs::Scheduled
    every 30.minutes

    LOCK_KEY = "aggregate_browser_pageview_daily_rollups"

    def execute(args)
      return if !SiteSetting.persist_browser_pageview_events

      start_date = 1.day.ago.to_date
      end_date = Time.zone.today

      DistributedMutex.synchronize(LOCK_KEY, validity: 2.hours) do
        BrowserPageviewCountryDailyRollup.aggregate(start_date: start_date, end_date: end_date)
        BrowserPageviewReferrerDailyRollup.aggregate(start_date: start_date, end_date: end_date)
      end
    end
  end
end
