# frozen_string_literal: true

RSpec.describe Jobs::DetectCrawlerPageviews do
  it "does nothing when detection is disabled" do
    SiteSetting.detect_crawler_pageviews = false
    CrawlerScorer.expects(:score_anonymous!).never

    described_class.new.execute({})
  end

  it "scores the last hour of anonymous pageviews when enabled" do
    SiteSetting.detect_crawler_pageviews = true
    freeze_time

    CrawlerScorer.expects(:score_anonymous!).with(window_start: 1.hour.ago, window_end: Time.now)

    described_class.new.execute({})
  end
end
