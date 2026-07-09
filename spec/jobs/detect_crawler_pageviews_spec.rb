# frozen_string_literal: true

RSpec.describe Jobs::DetectCrawlerPageviews do
  it "does nothing when detection is disabled" do
    SiteSetting.experimental_detect_crawler_pageviews = false
    CrawlerScorer.expects(:score!).never

    described_class.new.execute({})
  end

  it "scores an hour of pageviews ending at the beacon settle period when enabled" do
    SiteSetting.experimental_detect_crawler_pageviews = true
    freeze_time

    window_end = Time.now - described_class::WINDOW_DELAY
    CrawlerScorer.expects(:score!).with(
      window_start: window_end - described_class::LOOKBACK,
      window_end: window_end,
    )

    described_class.new.execute({})
  end
end
