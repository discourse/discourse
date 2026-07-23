# frozen_string_literal: true

RSpec.describe CrawlerScorer do
  def score!
    described_class.score!(window_start: 1.hour.ago, window_end: Time.now)
  end

  it "marks events without a session engagement as crawler" do
    event = Fabricate(:browser_pageview_event, created_at: 30.minutes.ago)

    score!

    expect(event.reload.crawler).to eq(true)
  end

  it "does not mark events with a session engagement as crawler" do
    event = Fabricate(:browser_pageview_event, created_at: 30.minutes.ago)
    Fabricate(:browser_pageview_session_engagement, session_id: event.session_id)

    score!

    expect(event.reload.crawler).to eq(false)
  end

  it "keeps events with an automation user agent as crawler even with a session engagement" do
    event =
      Fabricate(
        :browser_pageview_event,
        created_at: 30.minutes.ago,
        user_agent: "Mozilla/5.0 (X11; Linux x86_64) HeadlessChrome/120.0.0.0",
      )
    Fabricate(:browser_pageview_session_engagement, session_id: event.session_id)

    score!

    expect(event.reload.crawler).to eq(true)
  end

  it "does not treat any user agent as automation when the setting is blank" do
    SiteSetting.crawler_automation_user_agents = ""
    event =
      Fabricate(
        :browser_pageview_event,
        created_at: 30.minutes.ago,
        user_agent: "Mozilla/5.0 (X11; Linux x86_64) HeadlessChrome/120.0.0.0",
      )
    Fabricate(:browser_pageview_session_engagement, session_id: event.session_id)

    score!

    expect(event.reload.crawler).to eq(false)
  end

  it "unmarks previously marked events once an engagement shows up" do
    event = Fabricate(:browser_pageview_event, created_at: 30.minutes.ago, crawler: true)
    Fabricate(:browser_pageview_session_engagement, session_id: event.session_id)

    score!

    expect(event.reload.crawler).to eq(false)
  end

  it "leaves events outside the window untouched" do
    too_old = Fabricate(:browser_pageview_event, created_at: 2.hours.ago)
    too_fresh = Fabricate(:browser_pageview_event, created_at: 1.minute.from_now)

    score!

    expect(too_old.reload.crawler).to eq(false)
    expect(too_fresh.reload.crawler).to eq(false)
  end
end
