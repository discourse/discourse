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
    expect(event.reload.score).to eq(140)
  end

  it "writes the score breakdown per heuristic to the side table" do
    SiteSetting.crawler_asns = "12345"
    event =
      make_event(
        user_agent: "Mozilla/5.0 (X11; Linux x86_64) HeadlessChrome/120.0.0.0",
        asn: 12_345,
      )

    score!

    expect(event.reload.score).to eq(170)
    breakdown = event.browser_pageview_event_score
    expect(breakdown.automation_ua_score).to eq(100)
    expect(breakdown.known_asn_score).to eq(30)
    expect(breakdown.datacenter_asn_score).to eq(0)
    expect(breakdown.single_request_no_referrer_score).to eq(0)
    expect(breakdown.stale_browser_score).to eq(0)
    expect(breakdown.velocity_score).to eq(0)
    expect(breakdown.churn_score).to eq(0)
    expect(breakdown.rapid_nav_score).to eq(0)
    expect(breakdown.ip_rotation_score).to eq(0)
    expect(breakdown.referrer_score).to eq(0)
    expect(breakdown.engagement_score).to eq(40)
  end

  it "does not score an event whose only signal is missing engagement" do
    event = make_event

    score!

    expect(event.reload.score).to be_nil
    expect(event.browser_pageview_event_score).to be_nil
  end

  it "scores known crawler ASNs at +30" do
    SiteSetting.crawler_asns = "12345"
    event = make_event(asn: 12_345)
    score!
    expect(event.reload.score).to eq(70)
  end

  it "scores datacenter ASNs at +10" do
    SiteSetting.crawler_asns = ""
    SiteSetting.crawler_detection_datacenter_asns = "12345"
    event = make_event(asn: 12_345)

    score!

    expect(event.reload.score).to eq(50)
    expect(event.browser_pageview_event_score.datacenter_asn_score).to eq(10)
  end

  it "scores unengaged single direct requests at +10" do
    event = make_event(referrer: nil)

    score!

    expect(event.reload.score).to eq(50)
    expect(event.browser_pageview_event_score.single_request_no_referrer_score).to eq(10)
  end

  it "scores unengaged single direct requests with any translation parameter at +15" do
    event = make_event(url: "/t/topic/1?source=bot&tl=made-up-locale", referrer: nil)

    score!

    expect(event.reload.score).to eq(55)
    expect(event.browser_pageview_event_score.single_request_no_referrer_score).to eq(15)
  end

  it "scores unengaged Chromium versions at or below the configured cutoff at +5" do
    SiteSetting.crawler_stale_chromium_major_version_cutoff = 138
    event = make_event(user_agent: "Mozilla/5.0 Chrome/138.0.0.0 Safari/537.36")

    score!

    expect(event.reload.score).to eq(45)
    expect(event.browser_pageview_event_score.stale_browser_score).to eq(5)
  end

  it "does not score Chromium versions above the configured cutoff" do
    SiteSetting.crawler_stale_chromium_major_version_cutoff = 138
    event = make_event(user_agent: "Mozilla/5.0 Chrome/139.0.0.0 Safari/537.36")

    score!

    expect(event.reload.score).to be_nil
    expect(event.browser_pageview_event_score).to be_nil
  end

  it "does not score oversized Chromium major versions as stale" do
    event = make_event(user_agent: "Mozilla/5.0 Chrome/99999999999.0.0.0 Safari/537.36")

    score!

    expect(event.reload.score).to be_nil
    expect(event.browser_pageview_event_score).to be_nil
  end

  it "does not score stale Chromium versions when the session has interaction" do
    SiteSetting.crawler_asns = "12345"
    event = make_event(asn: 12_345, user_agent: "Mozilla/5.0 Chrome/125.0.0.0 Safari/537.36")
    Fabricate(:browser_pageview_session_engagement, session_id: event.session_id, click_events: 1)

    score!

    expect(event.reload.score).to eq(30)
    expect(event.browser_pageview_event_score.stale_browser_score).to eq(0)
  end

  it "scores stale Chromium versions reported by Edge and Opera" do
    SiteSetting.crawler_stale_chromium_major_version_cutoff = 138
    edge_event = make_event(user_agent: "Mozilla/5.0 Chrome/125.0.0.0 Safari/537.36 Edg/125.0.0.0")
    opera_event = make_event(user_agent: "Mozilla/5.0 Chrome/125.0.0.0 Safari/537.36 OPR/110.0.0.0")

    score!

    expect([edge_event.reload.score, opera_event.reload.score]).to eq([45, 45])
    expect(
      [
        edge_event.browser_pageview_event_score.stale_browser_score,
        opera_event.browser_pageview_event_score.stale_browser_score,
      ],
    ).to eq([5, 5])
  end

  it "scores pageview velocity at or above VELOCITY_LOW threshold at +15" do
    stub_const(CrawlerScorer, :VELOCITY_LOW, 10) do
      session_id = "burst-session"
      base = 30.minutes.ago
      10.times { |i| make_event(session_id: session_id, created_at: base + (i * 15).seconds) }

      score!

      expect(
        BrowserPageviewEvent.where(session_id: session_id).pluck(:score).uniq,
      ).to contain_exactly(55)
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
      ).to contain_exactly(60)
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
      ).to contain_exactly(55)
    end
  end

  it "scores ip rotation when one session is replayed through several addresses" do
    base = 30.minutes.ago
    %w[202.46.62.21 202.46.62.55 202.46.62.97].each_with_index do |ip, i|
      make_event(ip_address: ip, session_id: "rotating-session", created_at: base + (i * 5).seconds)
    end

    score!

    expect(
      BrowserPageviewEvent.where(session_id: "rotating-session").pluck(:score).uniq,
    ).to contain_exactly(70)
  end

  it "scores ip rotation the same whether or not the addresses cross ASNs" do
    base = 30.minutes.ago
    [
      ["202.46.62.21", 64_496],
      ["202.46.62.55", 64_496],
      ["1.2.3.9", 64_497],
    ].each_with_index do |(ip, asn), i|
      make_event(
        ip_address: ip,
        asn: asn,
        session_id: "cross-asn-session",
        created_at: base + (i * 5).seconds,
      )
    end

    score!

    expect(
      BrowserPageviewEvent.where(session_id: "cross-asn-session").pluck(:score).uniq,
    ).to contain_exactly(70)
  end

  it "does not add an IP rotation score to a session that only uses two addresses" do
    base = 30.minutes.ago
    %w[10.0.0.1 10.0.0.2].each_with_index do |ip, i|
      make_event(ip_address: ip, session_id: "handover-session", created_at: base + (i * 5).seconds)
    end

    score!

    expect(BrowserPageviewEvent.where(session_id: "handover-session").pluck(:score).uniq).to eq(
      [nil],
    )
  end

  it "does not add an IP rotation score to a slow network handover" do
    base = 40.minutes.ago
    %w[10.0.0.1 10.0.0.2 10.0.0.3].each_with_index do |ip, i|
      make_event(ip_address: ip, session_id: "slow-session", created_at: base + (i * 11).minutes)
    end

    score!

    expect(BrowserPageviewEvent.where(session_id: "slow-session").pluck(:score).uniq).to eq([nil])
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
      ).to contain_exactly(50)
    end
  end

  it "also scores logged-in events" do
    user = Fabricate(:user)
    event = make_event(user_id: user.id, user_agent: "Mozilla/5.0 HeadlessChrome/120.0.0.0")

    score!

    expect(event.reload.score).to eq(140)
  end

  it "ignores events outside the window" do
    event = make_event(user_agent: "HeadlessChrome/120", created_at: 2.hours.ago)

    score!

    expect(event.reload.score).to be_nil
  end

  it "does not penalise events whose session shows human interaction" do
    event = make_event(user_agent: "Mozilla/5.0 HeadlessChrome/120.0.0.0")
    Fabricate(
      :browser_pageview_session_engagement,
      session_id: event.session_id,
      mouse_move_events: 5,
      click_events: 2,
    )

    score!

    expect(event.reload.score).to eq(100)
    expect(event.browser_pageview_event_score.engagement_score).to eq(0)
  end

  it "never scores an event below its bot signals" do
    SiteSetting.crawler_asns = "12345"
    event = make_event(asn: 12_345)
    Fabricate(:browser_pageview_session_engagement, session_id: event.session_id, scroll_events: 3)

    score!

    expect(event.reload.score).to eq(30)
    breakdown = event.browser_pageview_event_score
    expect(breakdown.known_asn_score).to eq(30)
    expect(breakdown.datacenter_asn_score).to eq(0)
    expect(breakdown.engagement_score).to eq(0)
  end

  it "treats any engagement row as engagement, since the client only beacons on activity" do
    event = make_event(user_agent: "Mozilla/5.0 HeadlessChrome/120.0.0.0")
    Fabricate(
      :browser_pageview_session_engagement,
      session_id: event.session_id,
      engaged_seconds: 30,
    )

    score!

    expect(event.reload.score).to eq(100)
    expect(event.browser_pageview_event_score.engagement_score).to eq(0)
  end

  it "lowers the score when an engagement beacon arrives after an earlier run" do
    SiteSetting.crawler_asns = "12345"
    event = make_event(asn: 12_345)

    score!
    expect(event.reload.score).to eq(70)

    Fabricate(:browser_pageview_session_engagement, session_id: event.session_id, key_events: 4)
    score!

    expect(event.reload.score).to eq(30)
    expect(event.browser_pageview_event_score.engagement_score).to eq(0)
  end

  it "does not penalise an unengaged session when most of the ip+ua traffic is engaged" do
    SiteSetting.crawler_asns = "12345"
    base = 30.minutes.ago
    engaged_session = "engaged-session"
    10.times do |i|
      make_event(asn: 12_345, session_id: engaged_session, created_at: base + i.minutes)
    end
    Fabricate(:browser_pageview_session_engagement, session_id: engaged_session, scroll_events: 8)

    abandoned_tab = make_event(asn: 12_345, session_id: "abandoned-tab", created_at: base)

    score!

    expect(abandoned_tab.reload.score).to eq(30)
    expect(abandoned_tab.browser_pageview_event_score.engagement_score).to eq(0)
  end

  it "dilutes the ratio with engaged traffic that precedes the scoring window" do
    SiteSetting.crawler_asns = "12345"
    engaged_session = "earlier-engaged"
    10.times do |i|
      make_event(asn: 12_345, session_id: engaged_session, created_at: 3.hours.ago + i.minutes)
    end
    Fabricate(:browser_pageview_session_engagement, session_id: engaged_session, scroll_events: 8)

    tail = 3.times.map { |i| make_event(asn: 12_345, created_at: 30.minutes.ago + i.minutes) }

    score!

    tail.each do |event|
      expect(event.reload.score).to eq(30)
      expect(event.browser_pageview_event_score.engagement_score).to eq(0)
    end
  end

  it "still penalises a single unengaged request with no other traffic on the horizon" do
    SiteSetting.crawler_asns = "12345"
    event = make_event(asn: 12_345)

    score!

    expect(event.reload.score).to eq(70)
    expect(event.browser_pageview_event_score.engagement_score).to eq(40)
  end

  it "ignores engaged traffic older than the lookback horizon" do
    SiteSetting.crawler_asns = "12345"
    engaged_session = "long-ago-engaged"
    10.times do |i|
      make_event(asn: 12_345, session_id: engaged_session, created_at: 7.hours.ago + i.minutes)
    end
    Fabricate(:browser_pageview_session_engagement, session_id: engaged_session, scroll_events: 8)

    event = make_event(asn: 12_345)

    score!

    expect(event.reload.score).to eq(70)
    expect(event.browser_pageview_event_score.engagement_score).to eq(40)
  end

  it "scores partially engaged ip+ua traffic at the lower band" do
    SiteSetting.crawler_asns = "12345"
    base = 30.minutes.ago
    engaged_session = "partly-engaged"
    make_event(asn: 12_345, session_id: engaged_session, created_at: base)
    Fabricate(:browser_pageview_session_engagement, session_id: engaged_session, click_events: 2)

    3.times do |i|
      make_event(asn: 12_345, session_id: "unengaged-#{i}", created_at: base + (i + 1).minutes)
    end

    score!

    expect(BrowserPageviewEvent.where(session_id: "unengaged-0").first.score).to eq(50)
    expect(
      BrowserPageviewEvent
        .where(session_id: "unengaged-0")
        .first
        .browser_pageview_event_score
        .engagement_score,
    ).to eq(20)
  end

  it "scores each source but partitions velocity so transports do not inflate each other" do
    stub_const(CrawlerScorer, :VELOCITY_LOW, 10) do
      stub_const(CrawlerScorer, :VELOCITY_MEDIUM, 20) do
        base = 30.minutes.ago

        # Same ip+ua, split across two transports with 12 pageviews each. On
        # its own each source sits in the LOW velocity tier (+15). Combined they
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
        ).to contain_exactly(55)
        expect(
          BrowserPageviewEvent
            .where(source: BrowserPageviewEvent::SOURCE_BEACON)
            .pluck(:score)
            .uniq,
        ).to contain_exactly(55)
      end
    end
  end
end
