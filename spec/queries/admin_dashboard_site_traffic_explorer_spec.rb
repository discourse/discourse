# frozen_string_literal: true

RSpec.describe AdminDashboardSiteTrafficExplorer do
  describe ".call" do
    before do
      freeze_time(Time.zone.local(2026, 5, 14, 12, 0, 0))
      SiteSetting.improved_crawler_detection = true
      SiteSetting.persist_browser_pageview_events = true
      SiteSetting.use_legacy_pageviews = false
      BrowserPageviewEvent.stubs(:beacon_cutover_date).returns(Date.new(2026, 1, 1))
    end

    let(:params) { { start_date: "2026-05-01", end_date: "2026-05-12" } }

    let(:user_agents) do
      [
        "Mozilla/5.0 Chrome/124.0 Safari/537.36 Edg/124.0",
        "Mozilla/5.0 Chrome/124.0 Safari/537.36 OPR/109.0",
        "Mozilla/5.0 Firefox/126.0",
        "Mozilla/5.0 FxiOS/126.0 Mobile/15E148 Safari/605.1.15",
        "Mozilla/5.0 CriOS/124.0 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 Version/17.0 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 SamsungBrowser/24.0 Chrome/120.0 Mobile Safari/537.36",
        "Mozilla/5.0 Vivaldi/6.7 Chrome/124.0 Safari/537.36",
        "Mozilla/5.0 Trident/7.0; rv:11.0",
        "Discourse/163 CFNetwork/978.0.7 Darwin/18.6.0",
        "ExampleBrowser/1.0",
      ]
    end

    let!(:pageviews) do
      user_agents.each_with_index do |user_agent, index|
        Fabricate(
          :browser_pageview_event,
          url: "/browser-#{index}",
          country_code: "US",
          asn: 64_496,
          ip_address: "192.0.2.#{index + 1}",
          session_id: "browser-#{index}",
          source: BrowserPageviewEvent::SOURCE_BEACON,
          user_agent:,
          created_at: Time.zone.local(2026, 5, 10, 10, index),
        )
      end
    end

    it "classifies supported major browsers and groups other user agents as unknown" do
      browsers = described_class.call(params).dig(:dimensions, "browsers")

      expect(browsers).to eq(
        [
          { value: "unknown", label: "Unknown browser", pageviews: 6 },
          { value: "firefox", label: "Firefox", pageviews: 2 },
          { value: "chrome", label: "Chrome", pageviews: 1 },
          { value: "edge", label: "Microsoft Edge", pageviews: 1 },
          { value: "safari", label: "Safari", pageviews: 1 },
        ],
      )
    end

    it "uses only local IP data to produce country and network labels" do
      DiscourseIpInfo
        .expects(:get)
        .with("192.0.2.1", locale: I18n.locale, resolve_hostname: false)
        .twice
        .returns(
          country_code: "US",
          country: "United States",
          asn: 64_496,
          organization: "Example Network",
        )

      dimensions = described_class.call(params).fetch(:dimensions)

      expect(dimensions.slice("countries", "networks")).to eq(
        "countries" => [{ value: "US", label: "United States", pageviews: 11 }],
        "networks" => [{ value: "AS64496", label: "Example Network (AS64496)", pageviews: 11 }],
      )
    end

    it "uses the canonical country code when local IP data has no localized country name" do
      DiscourseIpInfo.stubs(:get).returns(country_code: "US", asn: 64_496)

      countries =
        I18n.with_locale(:de) { described_class.call(params).dig(:dimensions, "countries") }

      expect(countries).to eq([{ value: "US", label: "US", pageviews: 11 }])
    end

    it "labels active country and network filters independently of their intersection" do
      Fabricate(
        :browser_pageview_event,
        country_code: "GB",
        asn: 64_500,
        ip_address: "198.51.100.1",
        session_id: "other-network",
        source: BrowserPageviewEvent::SOURCE_BEACON,
        created_at: Time.zone.local(2026, 5, 10, 11),
      )
      DiscourseIpInfo
        .stubs(:get)
        .with("192.0.2.1", locale: I18n.locale, resolve_hostname: false)
        .returns(country_code: "US", country: "United States", asn: 64_496)
      DiscourseIpInfo
        .stubs(:get)
        .with("198.51.100.1", locale: I18n.locale, resolve_hostname: false)
        .returns(asn: 64_500, organization: "Other Network")

      result = described_class.call(params.merge(country: "US", network: "AS64500"))

      expect(result.slice(:summary, :active_filters)).to eq(
        summary: {
          "pageviews" => 0,
          "distinct_sessions" => 0,
          "logged_in_share" => 0,
          "bounce_rate" => 0,
          "average_session_duration_seconds" => 0,
        },
        active_filters: [
          { key: :country, value: "US", label: "United States" },
          { key: :network, value: "AS64500", label: "Other Network (AS64500)" },
        ],
      )
    end

    it "runs one read-only analytics statement with a ten-second deadline" do
      query_row = {
        "pageview_limited" => false,
        "summary" => {
        },
        "series" => [],
        "dimensions" => {
        },
        "active_filter_representative_ips" => {
          "country" => nil,
          "network" => nil,
        },
      }
      DB.expects(:exec).with("SET TRANSACTION READ ONLY").once
      DB.expects(:exec).with("SET LOCAL statement_timeout = 10000").once
      DB.expects(:query_hash).once.returns([query_row])

      described_class.call(params)
    end

    it "rolls back a timed-out statement and leaves the connection usable" do
      transaction_depth = ActiveRecord::Base.connection.open_transactions
      DB.stubs(:query_hash).raises(ActiveRecord::QueryCanceled, "statement timeout")

      expect { described_class.call(params) }.to raise_error(ActiveRecord::QueryCanceled)
      expect([ActiveRecord::Base.connection.open_transactions, DB.query_single("SELECT 1")]).to eq(
        [transaction_depth, [1]],
      )
    end

    it "includes newly persisted traffic in a later call" do
      before_pageviews = described_class.call(params).dig(:summary, "pageviews")
      Fabricate(
        :browser_pageview_event,
        url: "/new-pageview",
        ip_address: "198.51.100.1",
        session_id: "new-pageview",
        source: BrowserPageviewEvent::SOURCE_BEACON,
        user_agent: "ExampleBrowser/1.0",
        created_at: Time.zone.local(2026, 5, 11, 10),
      )
      after_pageviews = described_class.call(params).dig(:summary, "pageviews")

      expect([before_pageviews, after_pageviews]).to eq([11, 12])
    end

    it "does not promote a continuing session to an entry within the selected range" do
      Fabricate(
        :browser_pageview_event,
        url: "/outside-range-entry",
        normalized_referrer: "external.example/path",
        session_id: "continuing-session",
        source: BrowserPageviewEvent::SOURCE_BEACON,
        created_at: Time.zone.local(2026, 4, 30, 23, 59),
      )
      Fabricate(
        :browser_pageview_event,
        url: "/inside-range-continuation",
        normalized_referrer: "test.localhost/internal",
        session_id: "continuing-session",
        source: BrowserPageviewEvent::SOURCE_BEACON,
        created_at: Time.zone.local(2026, 5, 10, 12),
      )

      result = described_class.call(params)

      expect(
        [
          result.dig(:summary, "pageviews"),
          result.dig(:dimensions, "entry_urls").sum { |row| row[:pageviews] },
          result.dig(:dimensions, "referrers"),
        ],
      ).to eq([12, 11, [{ value: "", label: "Direct / unknown", pageviews: 11 }]])
    end

    it "does not promote a capped session continuation to an entry" do
      SiteSetting.stubs(:admin_site_traffic_event_cap).returns(1)
      Fabricate(
        :browser_pageview_event,
        url: "/capped-session-entry",
        normalized_referrer: "external.example/path",
        session_id: "capped-session",
        source: BrowserPageviewEvent::SOURCE_BEACON,
        created_at: Time.zone.local(2026, 5, 11, 10),
      )
      Fabricate(
        :browser_pageview_event,
        url: "/capped-session-continuation",
        normalized_referrer: "test.localhost/internal",
        session_id: "capped-session",
        source: BrowserPageviewEvent::SOURCE_BEACON,
        created_at: Time.zone.local(2026, 5, 11, 11),
      )

      result = described_class.call(params)

      expect(
        [
          result.dig(:summary, "pageviews"),
          result.dig(:dimensions, "entry_urls"),
          result.dig(:dimensions, "referrers"),
          result.dig(:partial_data, :reason),
        ],
      ).to eq([1, [], [], "pageview_limit"])
    end

    it "uses the earliest event id to break a session entry timestamp tie" do
      created_at = Time.zone.local(2026, 5, 11, 10)
      Fabricate(
        :browser_pageview_event,
        url: "/first-at-timestamp",
        session_id: "same-timestamp",
        source: BrowserPageviewEvent::SOURCE_BEACON,
        created_at:,
      )
      Fabricate(
        :browser_pageview_event,
        url: "/second-at-timestamp",
        session_id: "same-timestamp",
        source: BrowserPageviewEvent::SOURCE_BEACON,
        created_at:,
      )

      entry_urls = described_class.call(params).dig(:dimensions, "entry_urls")

      expect(entry_urls.select { |row| row[:value].end_with?("-at-timestamp") }).to eq(
        [{ value: "/first-at-timestamp", label: "/first-at-timestamp", pageviews: 1 }],
      )
    end
  end
end
