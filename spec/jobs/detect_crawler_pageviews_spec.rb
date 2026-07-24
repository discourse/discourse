# frozen_string_literal: true

RSpec.describe Jobs::DetectCrawlerPageviews do
  it "does nothing when detection is disabled" do
    SiteSetting.experimental_detect_crawler_pageviews = false
    CrawlerScorer.expects(:score!).never

    described_class.new.execute({})
  end

  it "scores the last hour of pageviews when enabled" do
    SiteSetting.experimental_detect_crawler_pageviews = true
    freeze_time

    CrawlerScorer.expects(:score!).with(window_start: 1.hour.ago, window_end: Time.now)

    described_class.new.execute({})
  end
end
