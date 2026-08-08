# frozen_string_literal: true

RSpec.describe Jobs::DetectCrawlerPageviews do
  it "does nothing when the improved crawler detection change is disabled" do
    SiteSetting.improved_crawler_detection = false
    CrawlerScorer.expects(:score!).never

    described_class.new.execute({})
  end

  it "scores a one hour wide window, held back by the beacon settle period" do
    SiteSetting.improved_crawler_detection = true
    freeze_time

    CrawlerScorer.expects(:score!).with(window_start: 90.minutes.ago, window_end: 30.minutes.ago)

    described_class.new.execute({})
  end
end
