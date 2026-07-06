# frozen_string_literal: true

RSpec.describe CrawlerScorer do
  let(:hostname) { Discourse.current_hostname }

  def make_event(opts = {})
    defaults = {
      url: "/t/topic/1",
      ip_address: "1.2.3.4",
      user_agent: "Mozilla/5.0",
      session_id: SecureRandom.hex(8),
      created_at: 30.minutes.ago,
      referrer: "https://#{hostname}/",
    }
    BrowserPageviewEvent.create!(defaults.merge(opts))
  end

  def score!
    described_class.score!(window_start: 1.hour.ago, window_end: Time.now)
  end

  it "scores automation user agents at +100" do
    event = make_event(user_agent: "Mozilla/5.0 (X11; Linux x86_64) HeadlessChrome/120.0.0.0")
    score!
    expect(event.reload.score).to eq(100)
  end

  it "writes the score breakdown per heuristic to the side table" do
    SiteSetting.crawler_asns = "12345"
    event =
      make_event(
        user_agent: "Mozilla/5.0 (X11; Linux x86_64) HeadlessChrome/120.0.0.0",
        asn: 12_345,
      )

    score!

    expect(event.reload.score).to eq(115)
    breakdown = event.browser_pageview_event_score
    expect(breakdown.automation_ua_score).to eq(100)
    expect(breakdown.known_asn_score).to eq(15)
    expect(breakdown.velocity_score).to eq(0)
    expect(breakdown.churn_score).to eq(0)
    expect(breakdown.rapid_nav_score).to eq(0)
    expect(breakdown.referrer_score).to eq(0)
  end

  it "does not write a breakdown row for events that score 0" do
    event = make_event
    score!
    expect(event.reload.score).to be_nil
    expect(event.browser_pageview_event_score).to be_nil
  end

  it "scores known crawler ASNs at +15" do
    SiteSetting.crawler_asns = "12345"
    event = make_event(asn: 12_345)
    score!
    expect(event.reload.score).to eq(15)
  end

  it "scores pageview velocity at or above VELOCITY_LOW threshold at +10" do
    stub_const(CrawlerScorer, :VELOCITY_LOW, 10) do
      session_id = "burst-session"
      base = 30.minutes.ago
      10.times { |i| make_event(session_id: session_id, created_at: base + (i * 15).seconds) }

      score!

      expect(
        BrowserPageviewEvent.where(session_id: session_id).pluck(:score).uniq,
      ).to contain_exactly(10)
    end
  end

  it "scores session churn when one ip+ua spawns many short sessions" do
    stub_const(CrawlerScorer, :CHURN_HIGH_MIN_SESSIONS, 3) do
      3.times do |i|
        make_event(ip_address: "9.9.9.9", user_agent: "ScriptyBot/1.0", session_id: "churn-#{i}")
      end

      score!

      expect(
        BrowserPageviewEvent.where(ip_address: "9.9.9.9").pluck(:score).uniq,
      ).to contain_exactly(20)
    end
  end

  it "scores rapid navigation when the median gap is under 5 seconds" do
    stub_const(CrawlerScorer, :RAPID_NAV_MIN_GAPS, 3) do
      session_id = "rapid-session"
      base = 30.minutes.ago
      4.times { |i| make_event(session_id: session_id, created_at: base + i.seconds) }

      score!

      expect(
        BrowserPageviewEvent.where(session_id: session_id).pluck(:score).uniq,
      ).to contain_exactly(15)
    end
  end

  it "scores referrer discontinuity when most pageviews have no referrer" do
    stub_const(CrawlerScorer, :REFERRER_MIN_EVENTS, 2) do
      session_id = "ref-session"
      2.times do
        make_event(
          ip_address: "5.5.5.5",
          user_agent: "RefBot/1.0",
          session_id: session_id,
          referrer: nil,
        )
      end

      score!

      expect(
        BrowserPageviewEvent.where(ip_address: "5.5.5.5").pluck(:score).uniq,
      ).to contain_exactly(10)
    end
  end

  it "also scores logged-in events" do
    user = Fabricate(:user)
    event = make_event(user_id: user.id, user_agent: "Mozilla/5.0 HeadlessChrome/120.0.0.0")

    score!

    expect(event.reload.score).to eq(100)
  end

  it "ignores events outside the window" do
    event = make_event(user_agent: "HeadlessChrome/120", created_at: 2.hours.ago)

    score!

    expect(event.reload.score).to be_nil
  end

  it "only updates the score when the new value is higher" do
    event = make_event(user_agent: "Mozilla/5.0 HeadlessChrome/120")
    event.update!(score: 120)

    score!

    expect(event.reload.score).to eq(120)
  end

  it "discounts events whose session shows human interaction" do
    event = make_event(user_agent: "Mozilla/5.0 HeadlessChrome/120.0.0.0")
    Fabricate(
      :browser_pageview_session_engagement,
      session_id: event.session_id,
      mouse_move_events: 5,
      click_events: 2,
    )

    score!

    expect(event.reload.score).to eq(60)
    expect(event.browser_pageview_event_score.engagement_score).to eq(-40)
  end

  it "writes a zero score when the discount cancels all bot signals" do
    SiteSetting.crawler_asns = "12345"
    event = make_event(asn: 12_345)
    Fabricate(:browser_pageview_session_engagement, session_id: event.session_id, scroll_events: 3)

    score!

    expect(event.reload.score).to eq(0)
    breakdown = event.browser_pageview_event_score
    expect(breakdown.known_asn_score).to eq(15)
    expect(breakdown.engagement_score).to eq(-40)
  end

  it "does not discount engagement rows crafted without interaction counts" do
    event = make_event(user_agent: "Mozilla/5.0 HeadlessChrome/120.0.0.0")
    Fabricate(
      :browser_pageview_session_engagement,
      session_id: event.session_id,
      engaged_seconds: 30,
    )

    score!

    expect(event.reload.score).to eq(100)
  end

  it "does not lower a previously assigned score when engagement arrives later" do
    SiteSetting.crawler_asns = "12345"
    event = make_event(asn: 12_345)

    score!
    expect(event.reload.score).to eq(15)

    Fabricate(:browser_pageview_session_engagement, session_id: event.session_id, key_events: 4)
    score!

    expect(event.reload.score).to eq(15)
  end

  it "scores each source but partitions velocity so transports do not inflate each other" do
    stub_const(CrawlerScorer, :VELOCITY_LOW, 10) do
      stub_const(CrawlerScorer, :VELOCITY_MEDIUM, 20) do
        base = 30.minutes.ago

        # Same ip+ua, split across two transports with 12 pageviews each. On
        # its own each source sits in the LOW velocity tier (+10). Combined they
        # would be 24 pageviews and reach the MEDIUM tier (+20), so equal
        # per-source scores prove the heuristics stay partitioned by source.
        {
          BrowserPageviewEvent::SOURCE_PIGGYBACK => "piggyback-session",
          BrowserPageviewEvent::SOURCE_BEACON => "beacon-session",
        }.each do |source, session_id|
          12.times do |i|
            make_event(source: source, session_id: session_id, created_at: base + (i * 15).seconds)
          end
        end

        score!

        expect(
          BrowserPageviewEvent
            .where(source: BrowserPageviewEvent::SOURCE_PIGGYBACK)
            .pluck(:score)
            .uniq,
        ).to contain_exactly(10)
        expect(
          BrowserPageviewEvent
            .where(source: BrowserPageviewEvent::SOURCE_BEACON)
            .pluck(:score)
            .uniq,
        ).to contain_exactly(10)
      end
    end
  end
end
