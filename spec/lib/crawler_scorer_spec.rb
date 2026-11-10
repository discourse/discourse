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
    attributes = defaults.merge(opts)
    BrowserPageviewEvent.create!(
      {
        normalized_referrer:
          BrowserPageviewEventUrlNormalizer.normalize_referrer(attributes[:referrer]),
      }.merge(attributes),
    )
  end

  def score!
    described_class.score!(window_start: 1.hour.ago, window_end: Time.now)
  end

  it "scores automation user agents at +100" do
    event = make_event(user_agent: "Mozilla/5.0 (X11; Linux x86_64) HeadlessChrome/120.0.0.0")
    score!
    expect(event.reload.score).to eq(150)
  end

  it "writes the score breakdown per heuristic to the side table" do
    SiteSetting.crawler_asns = "12345"
    event =
      make_event(
        user_agent: "Mozilla/5.0 (X11; Linux x86_64) HeadlessChrome/120.0.0.0",
        asn: 12_345,
      )

    score!

    expect(event.reload.score).to eq(180)
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
    expect(breakdown.distributed_traffic_score).to eq(0)
    expect(breakdown.engagement_score).to eq(50)
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
    expect(event.reload.score).to eq(80)
  end

  it "scores datacenter ASNs at +10" do
    SiteSetting.crawler_asns = ""
    SiteSetting.crawler_detection_datacenter_asns = "12345"
    event = make_event(asn: 12_345)

    score!

    expect(event.reload.score).to eq(60)
    expect(event.browser_pageview_event_score.datacenter_asn_score).to eq(10)
  end

  it "scores unengaged single direct requests at +10" do
    event = make_event(referrer: nil)

    score!

    expect(event.reload.score).to eq(60)
    expect(event.browser_pageview_event_score.single_request_no_referrer_score).to eq(10)
  end

  it "scores unengaged single direct requests with any translation parameter at +15" do
    event = make_event(url: "/t/topic/1?source=bot&tl=made-up-locale", referrer: nil)

    score!

    expect(event.reload.score).to eq(65)
    expect(event.browser_pageview_event_score.single_request_no_referrer_score).to eq(15)
  end

  it "scores unengaged Chromium versions at or below the configured cutoff at +5" do
    SiteSetting.crawler_stale_chromium_major_version_cutoff = 138
    event = make_event(user_agent: "Mozilla/5.0 Chrome/138.0.0.0 Safari/537.36")

    score!

    expect(event.reload.score).to eq(55)
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
    Fabricate(
      :browser_pageview_session_engagement,
      session_id: event.session_id,
      click_events: 1,
      scroll_events: 3,
    )

    score!

    expect(event.reload.score).to eq(30)
    expect(event.browser_pageview_event_score.stale_browser_score).to eq(0)
  end

  it "scores stale Chromium versions reported by Edge and Opera" do
    SiteSetting.crawler_stale_chromium_major_version_cutoff = 138
    edge_event = make_event(user_agent: "Mozilla/5.0 Chrome/125.0.0.0 Safari/537.36 Edg/125.0.0.0")
    opera_event = make_event(user_agent: "Mozilla/5.0 Chrome/125.0.0.0 Safari/537.36 OPR/110.0.0.0")

    score!

    expect([edge_event.reload.score, opera_event.reload.score]).to eq([55, 55])
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
      ).to contain_exactly(65)
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
      ).to contain_exactly(70)
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
      ).to contain_exactly(65)
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
    ).to contain_exactly(80)
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
    ).to contain_exactly(80)
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
      ).to contain_exactly(60)
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
    Fabricate(
      :browser_pageview_session_engagement,
      session_id: event.session_id,
      scroll_events: 3,
      mouse_move_events: 6,
    )

    score!

    expect(event.reload.score).to eq(30)
    breakdown = event.browser_pageview_event_score
    expect(breakdown.known_asn_score).to eq(30)
    expect(breakdown.datacenter_asn_score).to eq(0)
    expect(breakdown.engagement_score).to eq(0)
  end

  it "does not treat a single interaction signal as engagement" do
    SiteSetting.crawler_asns = "12345"
    event = make_event(asn: 12_345)
    Fabricate(
      :browser_pageview_session_engagement,
      session_id: event.session_id,
      scroll_events: 40,
      engaged_seconds: 30,
    )

    score!

    expect(event.reload.score).to eq(80)
    expect(event.browser_pageview_event_score.engagement_score).to eq(50)
  end

  it "lowers the score when an engagement beacon arrives after an earlier run" do
    SiteSetting.crawler_asns = "12345"
    event = make_event(asn: 12_345)

    score!
    expect(event.reload.score).to eq(80)

    Fabricate(
      :browser_pageview_session_engagement,
      session_id: event.session_id,
      key_events: 4,
      mouse_move_events: 2,
    )
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
    Fabricate(
      :browser_pageview_session_engagement,
      session_id: engaged_session,
      scroll_events: 8,
      mouse_move_events: 12,
    )

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
    Fabricate(
      :browser_pageview_session_engagement,
      session_id: engaged_session,
      scroll_events: 8,
      mouse_move_events: 12,
    )

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

    expect(event.reload.score).to eq(80)
    expect(event.browser_pageview_event_score.engagement_score).to eq(50)
  end

  it "ignores engaged traffic older than the lookback horizon" do
    SiteSetting.crawler_asns = "12345"
    engaged_session = "long-ago-engaged"
    10.times do |i|
      make_event(asn: 12_345, session_id: engaged_session, created_at: 7.hours.ago + i.minutes)
    end
    Fabricate(
      :browser_pageview_session_engagement,
      session_id: engaged_session,
      scroll_events: 8,
      mouse_move_events: 12,
    )

    event = make_event(asn: 12_345)

    score!

    expect(event.reload.score).to eq(80)
    expect(event.browser_pageview_event_score.engagement_score).to eq(50)
  end

  it "scores partially engaged ip+ua traffic at the lower band" do
    SiteSetting.crawler_asns = "12345"
    base = 30.minutes.ago
    engaged_session = "partly-engaged"
    make_event(asn: 12_345, session_id: engaged_session, created_at: base)
    Fabricate(
      :browser_pageview_session_engagement,
      session_id: engaged_session,
      click_events: 2,
      mouse_move_events: 9,
    )

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

  it "uses 50 missing-engagement points for anonymous visits and 40 for logged-in visits" do
    anonymous = make_event(referrer: nil)
    logged_in = make_event(user_id: Fabricate(:user).id, ip_address: "1.2.3.5", referrer: nil)

    score!

    expect(anonymous.reload.score).to eq(60)
    expect(anonymous.browser_pageview_event_score.engagement_score).to eq(50)
    expect(logged_in.reload.score).to eq(50)
    expect(logged_in.browser_pageview_event_score.engagement_score).to eq(40)
  end

  describe ".score!" do
    it "preserves burst-only scores when the burst leaves the scoring window" do
      freeze_time
      events = 12.times.map { |index| make_event(created_at: 45.minutes.ago + index.seconds) }

      score!

      event = events.last
      original_score = event.reload.score
      expect(original_score).to be > described_class::BOT_SCORE_THRESHOLD
      expect(event.browser_pageview_event_score.distributed_traffic_score).to eq(0)

      described_class.score!(window_start: event.created_at, window_end: event.created_at + 1.hour)

      expect(event.reload.score).to eq(original_score)
    end

    context "with distributed traffic" do
      before { freeze_time }

      def make_cohort_events(count: 99, ip_count: count, **attributes)
        count.times.map do |index|
          make_event(
            {
              asn: 64_496,
              ip_address: "198.51.100.#{index % ip_count + 1}",
              created_at: 12.hours.ago,
            }.merge(attributes),
          )
        end
      end

      it "scores ASN cohorts at the minimum volume, IP, and session-ratio thresholds" do
        history = make_cohort_events(ip_count: 20)
        history.last(2).each { |previous| previous.update!(session_id: history.first.session_id) }
        event = make_event(asn: 64_496, ip_address: "198.51.100.20")

        score!

        expect(event.reload.score).to eq(110)
        expect(event.browser_pageview_event_score.distributed_traffic_score).to eq(60)
      end

      it "rejects referral cohorts when session navigation lowers the distinct-session ratio" do
        referrer = "https://www.google.com/"
        history = make_cohort_events(asn: nil, referrer: referrer)
        current = make_event(ip_address: "198.51.101.1", referrer: referrer)
        (history + [current]).each do |landing|
          2.times do |index|
            make_event(
              ip_address: landing.ip_address.to_s,
              session_id: landing.session_id,
              created_at: landing.created_at + (index + 1).seconds,
            )
          end
        end

        score!

        expect(current.reload.score).to be_nil
        expect(BrowserPageviewEvent.where(described_class.likely_crawler_condition)).to be_empty
      end

      it "counts each pageview once when a session repeats the same external referrer" do
        referrer = "https://referrer.example.com/"
        make_cohort_events(asn: nil, referrer: referrer)
        current = make_event(ip_address: "198.51.101.1", referrer: referrer)
        make_event(
          ip_address: current.ip_address.to_s,
          session_id: current.session_id,
          referrer: referrer,
          created_at: current.created_at + 1.second,
        )

        score!

        expect(current.reload.score).to eq(110)
        expect(current.browser_pageview_event_score.distributed_traffic_score).to eq(60)
      end

      it "keeps different external referrers separate" do
        make_cohort_events(asn: nil, referrer: "https://referrer.example.com/campaign")
        event =
          make_event(ip_address: "198.51.101.1", referrer: "https://referrer.example.com/other")

        score!

        expect(event.reload.score).to be_nil
      end

      it "scores a session using its earliest eligible external referrer" do
        landing_referrer = "https://referrer.example.com/landing"
        later_referrer = "https://referrer.example.com/later"
        make_cohort_events(asn: nil, referrer: landing_referrer)
        make_cohort_events(count: 100, asn: nil, referrer: later_referrer)
        later = make_event(referrer: later_referrer)
        landing =
          make_event(
            session_id: later.session_id,
            referrer: landing_referrer,
            created_at: later.created_at - 1.second,
          )

        score!

        expect(landing.reload.score).to eq(110)
        expect(later.reload.score).to be_nil
      end

      it "groups referral traffic across ASNs and tracking URL variants" do
        99.times do |index|
          make_event(
            ip_address: "198.51.100.#{index + 1}",
            asn: [nil, 64_496, 64_497][index % 3],
            referrer: "https://referrer.example.com/?utm_source=#{index}&fbclid=#{index}",
            created_at: 12.hours.ago,
          )
        end
        current = make_event(referrer: "https://referrer.example.com/?utm_source=current")

        score!

        expect(current.reload.score).to eq(110)
      end

      it "counts an event matching both cohort types only once" do
        referrer = "https://referrer.example.com/"
        make_cohort_events(referrer: referrer)
        event = make_event(asn: 64_496, ip_address: "198.51.101.1", referrer: referrer)

        score!

        expect(event.reload.score).to eq(110)
        expect(event.browser_pageview_event_score.distributed_traffic_score).to eq(60)
      end

      it "requires at least 100 pageviews in the cohort" do
        make_cohort_events(count: 98)
        event = make_event(asn: 64_496, ip_address: "198.51.101.1")

        score!

        expect(event.reload.score).to be_nil
      end

      it "requires at least 20 distinct IPs" do
        make_cohort_events(ip_count: 18)
        event = make_event(asn: 64_496, ip_address: "198.51.101.1")

        score!

        expect(event.reload.score).to be_nil
      end

      it "requires a distinct session for almost every pageview" do
        make_cohort_events(session_id: "shared-session")
        event = make_event(asn: 64_496, ip_address: "198.51.101.1")

        score!

        expect(event.reload.score).to be_nil
      end

      it "excludes engaged and logged-in events from distributed scoring" do
        make_cohort_events(count: 198)
        anonymous = make_event(asn: 64_496, ip_address: "198.51.101.1")
        engaged = make_event(asn: 64_496, ip_address: "198.51.101.2")
        logged_in =
          make_event(asn: 64_496, ip_address: "198.51.101.3", user_id: Fabricate(:user).id)
        Fabricate(
          :browser_pageview_session_engagement,
          session_id: engaged.session_id,
          click_events: 1,
          scroll_events: 2,
        )

        score!

        expect(anonymous.reload.score).to eq(110)
        expect(engaged.reload.score).to be_nil
        expect(logged_in.reload.score).to be_nil
      end

      it "excludes logged-in pageviews from the cohort sample" do
        make_cohort_events(user_id: Fabricate(:user).id)
        event = make_event(asn: 64_496, ip_address: "198.51.101.1")

        score!

        expect(event.reload.score).to be_nil
      end

      it "keeps different ASNs and user agents separate" do
        make_cohort_events
        different_asn = make_event(asn: 64_497, ip_address: "198.51.101.1")
        different_agent =
          make_event(asn: 64_496, ip_address: "198.51.101.2", user_agent: "AnotherBrowser/1.0")

        score!

        expect([different_asn.reload.score, different_agent.reload.score]).to eq([nil, nil])
      end

      it "excludes site aliases, internal URLs, and non-HTTP URLs from referral cohorts" do
        primary_hostname = hostname
        RailsMultisite::ConnectionManagement.stubs(:current_db_hostnames).returns(
          [primary_hostname, "alias.example.com"],
        )
        [
          "https://alias.example.com/",
          "ftp://external.example.com/",
          "https://#{hostname.upcase}:443/topic",
          "https://www.#{hostname}:443/",
          "https://#{hostname}/",
          "invalid-referrer",
        ].each_with_index do |referrer, index|
          user_agent = "Mozilla/5.0 variant-#{index}"
          make_cohort_events(asn: nil, referrer: referrer, user_agent: user_agent)
          make_event(ip_address: "198.51.101.1", referrer: referrer, user_agent: user_agent)
        end

        score!

        expect(BrowserPageviewEvent.where.not(score: nil)).to be_empty
      end

      it "limits cohort history to the 24 hours before the scoring window ends" do
        make_cohort_events(created_at: 24.hours.ago - 1.second)
        make_cohort_events(created_at: 1.second.from_now)
        event = make_event(asn: 64_496, ip_address: "198.51.101.1")

        score!

        expect(event.reload.score).to be_nil
      end

      it "rejects cohorts above the engagement ceiling" do
        history = make_cohort_events
        event = make_event(asn: 64_496, ip_address: "198.51.101.1")
        Fabricate(
          :browser_pageview_session_engagement,
          session_id: history.first.session_id,
          mouse_move_events: 2,
          scroll_events: 2,
        )

        score!

        expect(event.reload.score).to be_nil
      end

      it "clears obsolete distributed scores after late engagement while retaining other signals" do
        history = make_cohort_events
        event = make_event(asn: 64_496, ip_address: "198.51.101.1")
        direct = make_event(asn: 64_496, ip_address: "198.51.101.2", referrer: nil)

        score!

        expect(event.reload.score).to eq(110)
        expect(direct.reload.score).to eq(120)

        Fabricate(
          :browser_pageview_session_engagement,
          session_id: history.first.session_id,
          mouse_move_events: 2,
          scroll_events: 2,
        )

        score!

        expect(event.reload.score).to eq(0)
        expect(event.browser_pageview_event_score.reload.distributed_traffic_score).to eq(0)
        expect(event.browser_pageview_event_score.engagement_score).to eq(0)
        expect(direct.reload.score).to eq(60)
        expect(direct.browser_pageview_event_score.reload.distributed_traffic_score).to eq(0)
        expect(direct.browser_pageview_event_score.single_request_no_referrer_score).to eq(10)
        expect(direct.browser_pageview_event_score.engagement_score).to eq(50)
      end
    end
  end
end
