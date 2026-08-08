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
        "Mozilla/5.0 CriOS/124.0 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 Version/17.0 Mobile/15E148 Safari/604.1",
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

    it "keeps the SQL browser classifier aligned with BrowserDetection" do
      browsers = described_class.call(params).dig(:dimensions, "browsers")
      expected =
        user_agents
          .map { |user_agent| BrowserDetection.browser(user_agent).to_s }
          .tally
          .sort
          .map do |value, pageviews|
            { value:, label: I18n.t("admin_site_traffic_explorer.browsers.#{value}"), pageviews: }
          end

      expect(browsers).to eq(expected)
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
        "countries" => [{ value: "US", label: "United States", pageviews: 8 }],
        "networks" => [{ value: "AS64496", label: "AS64496 Example Network", pageviews: 8 }],
      )
    end

    it "uses the canonical country code when local IP data has no localized country name" do
      DiscourseIpInfo.stubs(:get).returns(country_code: "US", asn: 64_496)

      countries =
        I18n.with_locale(:de) { described_class.call(params).dig(:dimensions, "countries") }

      expect(countries).to eq([{ value: "US", label: "US", pageviews: 8 }])
    end

    it "runs one read-only analytics statement with a ten-second deadline" do
      query_row = {
        "pageview_limited" => false,
        "summary" => {
        },
        "series" => [],
        "dimensions" => {
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

      expect([before_pageviews, after_pageviews]).to eq([8, 9])
    end
  end
end
