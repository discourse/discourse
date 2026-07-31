# frozen_string_literal: true

RSpec.describe Jobs::DetectCrawlerPageviews do
  it "does nothing when detection is disabled" do
    SiteSetting.experimental_detect_crawler_pageviews = false
    CrawlerScorer.expects(:score!).never

    described_class.new.execute({})
  end

  it "scores a one hour wide window, held back by the beacon settle period" do
    SiteSetting.experimental_detect_crawler_pageviews = true
    freeze_time

    CrawlerScorer.expects(:score!).with(window_start: 90.minutes.ago, window_end: 30.minutes.ago)

    described_class.new.execute({})
  end
end
