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

  it "flags searches made from sessions the scoring pass marked as likely crawlers" do
    SiteSetting.improved_crawler_detection = true
    session_id = SecureRandom.hex(16)
    Fabricate(
      :browser_pageview_event,
      session_id: session_id,
      user_agent: "Mozilla/5.0 (X11; Linux x86_64) HeadlessChrome/120.0.0.0",
      created_at: 45.minutes.ago,
    )
    log = Fabricate(:search_log, user: nil, session_id: session_id, created_at: 45.minutes.ago)

    described_class.new.execute({})

    expect(log.reload.likely_crawler).to eq(true)
  end

  it "clears older search flags after distributed points replace an equal burst score" do
    SiteSetting.improved_crawler_detection = true
    freeze_time
    attributes = {
      asn: 64_496,
      user_agent: "Mozilla/5.0",
      referrer: "https://external.example.com/",
    }
    history =
      99.times.map do |index|
        Fabricate(
          :browser_pageview_event,
          **attributes,
          ip_address: "198.51.100.#{index + 1}",
          created_at: 20.minutes.ago,
        )
      end
    burst =
      150.times.map do |index|
        Fabricate(
          :browser_pageview_event,
          **attributes,
          ip_address: "198.51.101.1",
          created_at: 70.minutes.ago - (149 - index).seconds,
        )
      end
    event = burst.last
    log =
      Fabricate(:search_log, user: nil, session_id: event.session_id, created_at: 80.minutes.ago)

    described_class.new.execute({})
    expect(event.reload.score).to eq(110)
    expect(event.browser_pageview_event_score.distributed_traffic_score).to eq(0)
    expect(log.reload.likely_crawler).to eq(true)

    freeze_time 20.minutes.from_now
    described_class.new.execute({})

    expect(event.reload.score).to eq(110)
    expect(event.browser_pageview_event_score.reload.distributed_traffic_score).to eq(60)
    expect(event.browser_pageview_event_score.velocity_score).to eq(0)
    expect(event.browser_pageview_event_score.churn_score).to eq(0)
    expect(event.browser_pageview_event_score.rapid_nav_score).to eq(0)
    expect(event.browser_pageview_event_score.referrer_score).to eq(0)

    history
      .first(2)
      .each do |engaged|
        Fabricate(
          :browser_pageview_session_engagement,
          session_id: engaged.session_id,
          mouse_move_events: 2,
          scroll_events: 2,
        )
      end

    described_class.new.execute({})

    expect(event.reload.score).to eq(0)
    expect(event.browser_pageview_event_score.reload.distributed_traffic_score).to eq(0)
    expect(event.browser_pageview_event_score.engagement_score).to eq(0)
    expect(log.reload.likely_crawler).to eq(false)
    expect(SearchLog.human_only).to include(log)
  end
end
