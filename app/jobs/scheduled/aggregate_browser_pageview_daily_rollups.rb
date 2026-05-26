# frozen_string_literal: true

module Jobs
  class AggregateBrowserPageviewDailyRollups < ::Jobs::Scheduled
    every 30.minutes

    LOCK_KEY = "aggregate_browser_pageview_daily_rollups"

    def execute(args)
      return if !SiteSetting.persist_browser_pageview_events

      start_date, end_date = aggregation_window
      return if start_date.nil?

      DistributedMutex.synchronize(LOCK_KEY, validity: 10.minutes) do
        BrowserPageviewCountryDailyRollup.aggregate(start_date: start_date, end_date: end_date)
        BrowserPageviewReferrerDailyRollup.aggregate(start_date: start_date, end_date: end_date)
      end

      Report.clear_cache("top_countries_by_browser_pageviews")
      Report.clear_cache("top_referrers_by_browser_pageviews")
    end

    private

    def aggregation_window
      end_date = Time.zone.today

      if BrowserPageviewCountryDailyRollup.none? && BrowserPageviewReferrerDailyRollup.none?
        earliest_event_date = BrowserPageviewEvent.minimum(:created_at)&.to_date
        [earliest_event_date, end_date]
      else
        [1.day.ago.to_date, end_date]
      end
    end
  end
end
