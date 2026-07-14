# frozen_string_literal: true

module Jobs
  class DetectCrawlerPageviews < ::Jobs::Scheduled
    every 10.minutes

    LOOKBACK = 1.hour

    def execute(args)
      return if !SiteSetting.experimental_detect_crawler_pageviews

      now = Time.now
      CrawlerScorer.score!(window_start: now - LOOKBACK, window_end: now)
    end
  end
end
