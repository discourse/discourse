# frozen_string_literal: true

module Jobs
  class DetectCrawlerPageviews < ::Jobs::Scheduled
    every 10.minutes

    LOOKBACK = 1.hour
    WINDOW_DELAY = BrowserPageviewSessionEngagement::BEACON_SETTLE_PERIOD

    def execute(args)
      return if !UpcomingChanges.enabled?(:improved_crawler_detection)

      window_end = Time.now - WINDOW_DELAY
      CrawlerScorer.score!(window_start: window_end - LOOKBACK, window_end: window_end)
    end
  end
end
