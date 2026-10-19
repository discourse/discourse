# frozen_string_literal: true

module Jobs
  class DetectCrawlerPageviews < ::Jobs::Scheduled
    every 10.minutes

    LOOKBACK = 1.hour
    WINDOW_DELAY = BrowserPageviewSessionEngagement::BEACON_SETTLE_PERIOD

    def execute(args)
      return if !CrawlerScorer.enabled?

      window_end = Time.now - WINDOW_DELAY
      window_start = window_end - LOOKBACK

      CrawlerScorer.score!(window_start: window_start, window_end: window_end)
      SearchLog.flag_likely_crawlers!(window_start: window_start, window_end: window_end)
    end
  end
end
