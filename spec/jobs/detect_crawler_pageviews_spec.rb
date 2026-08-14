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

  it "flags anonymous searches that correlate with crawler traffic in the window" do
    SiteSetting.improved_crawler_detection = true
    user_agent = "Mozilla/5.0 (X11; Linux x86_64) HeadlessChrome/120.0.0.0"
    Fabricate(
      :browser_pageview_event,
      ip_address: "1.2.3.4",
      user_agent: user_agent,
      created_at: 45.minutes.ago,
    )
    log =
      Fabricate(
        :search_log,
        ip_address: "1.2.3.4",
        user_agent: user_agent,
        created_at: 45.minutes.ago,
      )

    described_class.new.execute({})

    expect(log.reload.likely_crawler).to eq(true)
  end
end
