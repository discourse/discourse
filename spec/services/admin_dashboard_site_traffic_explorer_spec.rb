# frozen_string_literal: true

RSpec.describe AdminDashboardSiteTrafficExplorer do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to validate_presence_of(:end_date) }

    it "requires the start date to precede the end date" do
      contract =
        described_class.new(start_date: Date.new(2026, 5, 13), end_date: Date.new(2026, 5, 12))

      expect(contract).not_to be_valid
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    let(:params) { { start_date: "2026-05-01", end_date: "2026-05-12" } }
    let(:dependencies) { {} }

    let(:browsers) do
      [
        nil,
        :unknown,
        :unknown,
        :unknown,
        :chrome,
        :chrome,
        :chrome,
        :safari,
        :safari,
        :edge,
        :firefox,
      ]
    end

    let!(:pageviews) do
      browsers.each_with_index do |browser, index|
        Fabricate(
          :browser_pageview_event,
          url: "/browser-#{index}",
          country_code: "US",
          asn: 64_496,
          ip_address: "192.0.2.#{index + 1}",
          session_id: "browser-#{index}",
          source: BrowserPageviewEvent::SOURCE_BEACON,
          browser:,
          created_at: Time.zone.local(2026, 5, 10, 10, index),
        )
      end
    end

    before do
      freeze_time(Time.zone.local(2026, 5, 14, 12, 0, 0))
      SiteSetting.improved_crawler_detection = true
      SiteSetting.persist_browser_pageview_events = true
      SiteSetting.use_legacy_pageviews = false
      BrowserPageviewEvent.stubs(:beacon_cutover_date).returns(Date.new(2026, 1, 1))
    end

    context "when the contract is invalid" do
      let(:params) { super().except(:start_date) }

      it { is_expected.to fail_a_contract }
    end

    context "when the query is canceled by Active Record" do
      before { DB.stubs(:query_hash).raises(ActiveRecord::QueryCanceled, "statement timeout") }

      it "returns the timeout failure and leaves the connection usable" do
        transaction_depth = ActiveRecord::Base.connection.open_transactions

        expect(result).to fail_a_step(:load_traffic)
        expect(result["result.step.load_traffic"].error).to eq("traffic_query_timeout")
        expect(
          [ActiveRecord::Base.connection.open_transactions, DB.query_single("SELECT 1")],
        ).to eq([transaction_depth, [1]])
      end
    end

    context "when the query is canceled by PostgreSQL" do
      before { DB.stubs(:query_hash).raises(PG::QueryCanceled, "statement timeout") }

      it "returns the named timeout failure" do
        expect(result).to fail_a_step(:load_traffic)
        expect(result["result.step.load_traffic"].error).to eq("traffic_query_timeout")
      end
    end

    context "when traffic contains password reset URLs" do
      let(:browsers) { [] }

      it "redacts password reset tokens from URL dimensions" do
        password_reset_token = "secret-token"
        reset_paths = %W[
          /u/password-reset/#{password_reset_token}
          /users/password-reset/#{password_reset_token}
        ]
        reset_paths.each_with_index do |path, index|
          Fabricate(
            :browser_pageview_event,
            url: path,
            normalized_url: path,
            ip_address: "192.0.2.1",
            session_id: "password-reset-#{index}",
            source: BrowserPageviewEvent::SOURCE_BEACON,
            browser: :chrome,
            created_at: Time.zone.local(2026, 5, 10, 11, index),
          )
        end

        expect(result.traffic.fetch(:dimensions)).to eq(
          "top_urls" => [
            {
              value: "/u/password-reset/<redacted>",
              label: "/u/password-reset/<redacted>",
              pageviews: 1,
            },
            {
              value: "/users/password-reset/<redacted>",
              label: "/users/password-reset/<redacted>",
              pageviews: 1,
            },
          ],
          "entry_urls" => [
            {
              value: "/u/password-reset/<redacted>",
              label: "/u/password-reset/<redacted>",
              pageviews: 1,
            },
            {
              value: "/users/password-reset/<redacted>",
              label: "/users/password-reset/<redacted>",
              pageviews: 1,
            },
          ],
          "referrers" => [{ value: "", label: "Direct / unknown", pageviews: 2 }],
          "countries" => [],
          "networks" => [],
          "browsers" => [{ value: "chrome", label: "Google Chrome", pageviews: 2 }],
          "ip_addresses" => [{ value: "192.0.2.1", label: "192.0.2.1", pageviews: 2 }],
        )
      end
    end

    context "when the query succeeds" do
      it { is_expected.to run_successfully }

      it "groups stored browser values and displays rows awaiting backfill as unknown" do
        browser_dimensions = result.traffic.dig(:dimensions, "browsers")

        expect(browser_dimensions).to eq(
          [
            { value: "unknown", label: "Unknown browser", pageviews: 4 },
            { value: "chrome", label: "Google Chrome", pageviews: 3 },
            { value: "safari", label: "Safari", pageviews: 2 },
            { value: "edge", label: "Microsoft Edge", pageviews: 1 },
            { value: "firefox", label: "Firefox", pageviews: 1 },
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

        dimensions = result.traffic.fetch(:dimensions)

        expect(dimensions.slice("countries", "networks")).to eq(
          "countries" => [{ value: "US", label: "United States", pageviews: 11 }],
          "networks" => [{ value: "AS64496", label: "Example Network (AS64496)", pageviews: 11 }],
        )
      end

      it "uses the canonical country code when local IP data has no localized country name" do
        DiscourseIpInfo.stubs(:get).returns(country_code: "US", asn: 64_496)

        countries = I18n.with_locale(:de) { result.traffic.dig(:dimensions, "countries") }

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

        traffic =
          described_class.call(params: params.merge(country: "US", network: "AS64500")).traffic

        expect(traffic.slice(:summary, :active_filters)).to eq(
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

      it "runs one analytics statement with a ten-second deadline" do
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
        DB.expects(:exec).with("SET LOCAL statement_timeout = 10000").once
        DB.expects(:query_hash).once.returns([query_row])

        expect(result).to run_successfully
      end

      it "includes newly persisted traffic in a later call" do
        before_pageviews = described_class.call(params:).traffic.dig(:summary, "pageviews")
        Fabricate(
          :browser_pageview_event,
          url: "/new-pageview",
          ip_address: "198.51.100.1",
          session_id: "new-pageview",
          source: BrowserPageviewEvent::SOURCE_BEACON,
          user_agent: "ExampleBrowser/1.0",
          created_at: Time.zone.local(2026, 5, 11, 10),
        )
        after_pageviews = described_class.call(params:).traffic.dig(:summary, "pageviews")

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

        traffic = result.traffic

        expect(
          [
            traffic.dig(:summary, "pageviews"),
            traffic.dig(:dimensions, "entry_urls").sum { |row| row[:pageviews] },
            traffic.dig(:dimensions, "referrers"),
          ],
        ).to eq([12, 11, [{ value: "", label: "Direct / unknown", pageviews: 11 }]])
      end

      it "groups acquisition entries by normalized referrer" do
        Fabricate(
          :browser_pageview_event,
          normalized_referrer: "external.example?article=traffic",
          session_id: "external-referrer-query",
          source: BrowserPageviewEvent::SOURCE_BEACON,
          created_at: Time.zone.local(2026, 5, 10, 12),
        )
        Fabricate(
          :browser_pageview_event,
          normalized_referrer: "test.localhost?view=latest",
          session_id: "local-referrer-query",
          source: BrowserPageviewEvent::SOURCE_BEACON,
          created_at: Time.zone.local(2026, 5, 10, 13),
        )
        expect(result.traffic.dig(:dimensions, "referrers")).to eq(
          [
            { value: "", label: "Direct / unknown", pageviews: 11 },
            {
              value: "external.example?article=traffic",
              label: "external.example?article=traffic",
              pageviews: 1,
            },
          ],
        )
      end

      it "does not report partial data when the population exactly matches the cap" do
        SiteSetting.site_traffic_explorer_event_limit = 11

        expect(result.traffic.slice(:partial_data, :summary)).to eq(
          partial_data: nil,
          summary: {
            "pageviews" => 11,
            "distinct_sessions" => 11,
            "logged_in_share" => 0,
            "bounce_rate" => 100,
            "average_session_duration_seconds" => 0,
          },
        )
      end

      it "does not promote a capped session continuation to an entry" do
        SiteSetting.site_traffic_explorer_event_limit = 1
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

        traffic = result.traffic

        expect(
          [
            traffic.dig(:summary, "pageviews"),
            traffic.dig(:dimensions, "entry_urls"),
            traffic.dig(:dimensions, "referrers"),
            traffic.dig(:partial_data, :reason),
          ],
        ).to eq([1, [], [], "pageview_limit"])
      end

      it "uses referrers rather than event ids to identify acquisition entries" do
        created_at = Time.zone.local(2026, 5, 11, 10)
        Fabricate(
          :browser_pageview_event,
          url: "/acquisition-at-timestamp",
          normalized_referrer: "external.example/path",
          session_id: "same-timestamp",
          source: BrowserPageviewEvent::SOURCE_BEACON,
          created_at:,
        )
        Fabricate(
          :browser_pageview_event,
          url: "/internal-at-timestamp",
          normalized_referrer: "test.localhost/acquisition-at-timestamp",
          session_id: "same-timestamp",
          source: BrowserPageviewEvent::SOURCE_BEACON,
          created_at:,
        )

        entry_urls = result.traffic.dig(:dimensions, "entry_urls")

        expect(entry_urls.select { |row| row[:value].end_with?("-at-timestamp") }).to eq(
          [
            {
              value: "/acquisition-at-timestamp",
              label: "/acquisition-at-timestamp",
              pageviews: 1,
            },
          ],
        )
      end
    end
  end
end
