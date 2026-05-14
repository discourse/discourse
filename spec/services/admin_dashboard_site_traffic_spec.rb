# frozen_string_literal: true

RSpec.describe AdminDashboardSiteTraffic do
  before do
    freeze_time(Time.zone.local(2026, 5, 14, 12, 0, 0))
    SiteSetting.use_legacy_pageviews = false
  end

  describe ".build" do
    it "returns public-community KPIs and pageview series for selected dates" do
      SiteSetting.embed_topics_list = true
      Fabricate(:embeddable_host)

      Fabricate(:logged_in_browser_application_request, date: "2026-04-28", count: 1)
      Fabricate(:anonymous_browser_application_request, date: "2026-04-29", count: 2)

      Fabricate(:logged_in_browser_application_request, date: "2026-05-01", count: 10)
      Fabricate(:anonymous_browser_application_request, date: "2026-05-02", count: 20)

      Fabricate(:embedded_application_request, date: "2026-05-02", count: 4)
      Fabricate(:crawler_application_request, date: "2026-05-03", count: 3)

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-03")).to eq(
        kpis: {
          browser_pageviews: {
            value: 30,
            percent_change: 900,
            comparison_period: {
              start_date: "2026-04-28",
              end_date: "2026-04-30",
            },
          },
          logged_in_share: {
            value: 33,
          },
        },
        pageview_series: [
          {
            id: "logged_in",
            default_visible: true,
            data: [
              { date: "2026-05-01", count: 10 },
              { date: "2026-05-02", count: 0 },
              { date: "2026-05-03", count: 0 },
            ],
          },
          {
            id: "anonymous",
            default_visible: true,
            data: [
              { date: "2026-05-01", count: 0 },
              { date: "2026-05-02", count: 20 },
              { date: "2026-05-03", count: 0 },
            ],
          },
          {
            id: "embedded",
            default_visible: true,
            data: [
              { date: "2026-05-01", count: 0 },
              { date: "2026-05-02", count: 4 },
              { date: "2026-05-03", count: 0 },
            ],
          },
          {
            id: "crawlers",
            default_visible: false,
            data: [
              { date: "2026-05-01", count: 0 },
              { date: "2026-05-02", count: 0 },
              { date: "2026-05-03", count: 3 },
            ],
          },
        ],
      )
    end

    it "returns a negative trend when current pageviews are below the comparison period" do
      Fabricate(:logged_in_browser_application_request, date: "2026-04-28", count: 20)

      Fabricate(:logged_in_browser_application_request, date: "2026-05-01", count: 5)

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-03")).to eq(
        kpis: {
          browser_pageviews: {
            value: 5,
            percent_change: -75,
            comparison_period: {
              start_date: "2026-04-28",
              end_date: "2026-04-30",
            },
          },
          logged_in_share: {
            value: 100,
          },
        },
        pageview_series: [
          {
            id: "logged_in",
            default_visible: true,
            data: [
              { date: "2026-05-01", count: 5 },
              { date: "2026-05-02", count: 0 },
              { date: "2026-05-03", count: 0 },
            ],
          },
          {
            id: "anonymous",
            default_visible: true,
            data: [
              { date: "2026-05-01", count: 0 },
              { date: "2026-05-02", count: 0 },
              { date: "2026-05-03", count: 0 },
            ],
          },
          {
            id: "crawlers",
            default_visible: false,
            data: [
              { date: "2026-05-01", count: 0 },
              { date: "2026-05-02", count: 0 },
              { date: "2026-05-03", count: 0 },
            ],
          },
        ],
      )
    end

    it "returns weekly buckets for longer selected date ranges" do
      Fabricate(:logged_in_browser_application_request, date: "2026-03-01", count: 1)
      Fabricate(:logged_in_browser_application_request, date: "2026-03-07", count: 2)
      Fabricate(:logged_in_browser_application_request, date: "2026-03-08", count: 4)
      Fabricate(:logged_in_browser_application_request, date: "2026-04-04", count: 8)
      Fabricate(:anonymous_browser_application_request, date: "2026-03-08", count: 10)

      response = described_class.build(start_date: "2026-03-01", end_date: "2026-04-04")
      logged_in_series =
        response[:pageview_series].find { |traffic_series| traffic_series[:id] == "logged_in" }
      anonymous_series =
        response[:pageview_series].find { |traffic_series| traffic_series[:id] == "anonymous" }

      expect(logged_in_series[:data]).to eq(
        [
          { date: "2026-03-01", end_date: "2026-03-07", count: 3 },
          { date: "2026-03-08", end_date: "2026-03-14", count: 4 },
          { date: "2026-03-15", end_date: "2026-03-21", count: 0 },
          { date: "2026-03-22", end_date: "2026-03-28", count: 0 },
          { date: "2026-03-29", end_date: "2026-04-04", count: 8 },
        ],
      )
      expect(anonymous_series[:data]).to eq(
        [
          { date: "2026-03-01", end_date: "2026-03-07", count: 0 },
          { date: "2026-03-08", end_date: "2026-03-14", count: 10 },
          { date: "2026-03-15", end_date: "2026-03-21", count: 0 },
          { date: "2026-03-22", end_date: "2026-03-28", count: 0 },
          { date: "2026-03-29", end_date: "2026-04-04", count: 0 },
        ],
      )
    end

    it "returns monthly buckets for year-long selected date ranges" do
      Fabricate(:logged_in_browser_application_request, date: "2025-01-01", count: 1)
      Fabricate(:logged_in_browser_application_request, date: "2025-01-31", count: 2)
      Fabricate(:logged_in_browser_application_request, date: "2025-02-01", count: 4)
      Fabricate(:logged_in_browser_application_request, date: "2025-12-31", count: 8)

      response = described_class.build(start_date: "2025-01-01", end_date: "2025-12-31")
      logged_in_series =
        response[:pageview_series].find { |traffic_series| traffic_series[:id] == "logged_in" }

      expect(logged_in_series[:data]).to eq(
        [
          { date: "2025-01-01", end_date: "2025-01-31", count: 3 },
          { date: "2025-02-01", end_date: "2025-02-28", count: 4 },
          { date: "2025-03-01", end_date: "2025-03-31", count: 0 },
          { date: "2025-04-01", end_date: "2025-04-30", count: 0 },
          { date: "2025-05-01", end_date: "2025-05-31", count: 0 },
          { date: "2025-06-01", end_date: "2025-06-30", count: 0 },
          { date: "2025-07-01", end_date: "2025-07-31", count: 0 },
          { date: "2025-08-01", end_date: "2025-08-31", count: 0 },
          { date: "2025-09-01", end_date: "2025-09-30", count: 0 },
          { date: "2025-10-01", end_date: "2025-10-31", count: 0 },
          { date: "2025-11-01", end_date: "2025-11-30", count: 0 },
          { date: "2025-12-01", end_date: "2025-12-31", count: 8 },
        ],
      )
    end

    it "omits trend data when the comparison period has no pageviews" do
      Fabricate(:logged_in_browser_application_request, date: "2026-04-01", count: 1)

      Fabricate(:logged_in_browser_application_request, date: "2026-05-01", count: 8)

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-03")[:kpis]).to eq(
        browser_pageviews: {
          value: 8,
        },
        logged_in_share: {
          value: 100,
        },
      )
    end

    it "omits trend data when current pageviews match the comparison period" do
      Fabricate(:logged_in_browser_application_request, date: "2026-04-28", count: 8)

      Fabricate(:logged_in_browser_application_request, date: "2026-05-01", count: 8)

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-03")[:kpis]).to eq(
        browser_pageviews: {
          value: 8,
        },
        logged_in_share: {
          value: 100,
        },
      )
    end

    it "omits trend data when the percentage change is below the display threshold" do
      Fabricate(:logged_in_browser_application_request, date: "2026-04-28", count: 200_000)

      Fabricate(:logged_in_browser_application_request, date: "2026-05-01", count: 200_001)

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-03")[:kpis]).to eq(
        browser_pageviews: {
          value: 200_001,
        },
        logged_in_share: {
          value: 100,
        },
      )
    end

    it "returns one decimal place for trend changes below one percent" do
      Fabricate(:logged_in_browser_application_request, date: "2026-04-28", count: 10_000)

      Fabricate(:logged_in_browser_application_request, date: "2026-05-01", count: 10_050)

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-03")[:kpis]).to eq(
        browser_pageviews: {
          value: 10_050,
          percent_change: 0.5,
          comparison_period: {
            start_date: "2026-04-28",
            end_date: "2026-04-30",
          },
        },
        logged_in_share: {
          value: 100,
        },
      )
    end

    it "returns whole numbers for trend changes of at least one percent" do
      Fabricate(:logged_in_browser_application_request, date: "2026-04-28", count: 100)

      Fabricate(:logged_in_browser_application_request, date: "2026-05-01", count: 110)

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-03")[:kpis]).to eq(
        browser_pageviews: {
          value: 110,
          percent_change: 10,
          comparison_period: {
            start_date: "2026-04-28",
            end_date: "2026-04-30",
          },
        },
        logged_in_share: {
          value: 100,
        },
      )
    end

    it "excludes mobile and beacon browser pageviews from totals and series" do
      Fabricate(:logged_in_browser_application_request, date: "2026-05-01", count: 10)
      Fabricate(:anonymous_browser_application_request, date: "2026-05-01", count: 20)

      Fabricate(:logged_in_browser_mobile_application_request, date: "2026-05-01", count: 100)
      Fabricate(:logged_in_browser_beacon_application_request, date: "2026-05-01", count: 200)
      Fabricate(:anonymous_browser_mobile_application_request, date: "2026-05-01", count: 300)
      Fabricate(:anonymous_browser_beacon_application_request, date: "2026-05-01", count: 400)

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-01")).to eq(
        kpis: {
          browser_pageviews: {
            value: 30,
          },
          logged_in_share: {
            value: 33,
          },
        },
        pageview_series: [
          { id: "logged_in", default_visible: true, data: [{ date: "2026-05-01", count: 10 }] },
          { id: "anonymous", default_visible: true, data: [{ date: "2026-05-01", count: 20 }] },
          { id: "crawlers", default_visible: false, data: [{ date: "2026-05-01", count: 0 }] },
        ],
      )
    end

    it "uses legacy human counters when legacy pageviews are enabled" do
      SiteSetting.use_legacy_pageviews = true

      Fabricate(:logged_in_application_request, date: "2026-05-01", count: 11)
      Fabricate(:anonymous_application_request, date: "2026-05-01", count: 22)

      Fabricate(:logged_in_browser_application_request, date: "2026-05-01", count: 110)
      Fabricate(:anonymous_browser_application_request, date: "2026-05-01", count: 220)

      Fabricate(:crawler_application_request, date: "2026-05-01", count: 4)

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-01")).to eq(
        kpis: {
          browser_pageviews: {
            value: 33,
          },
          logged_in_share: {
            value: 33,
          },
        },
        pageview_series: [
          { id: "logged_in", default_visible: true, data: [{ date: "2026-05-01", count: 11 }] },
          { id: "anonymous", default_visible: true, data: [{ date: "2026-05-01", count: 22 }] },
          { id: "crawlers", default_visible: false, data: [{ date: "2026-05-01", count: 4 }] },
        ],
      )
    end

    it "only includes embedded traffic when embedding is configured" do
      Fabricate(:embedded_application_request, date: "2026-05-01", count: 7)

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-01")).to eq(
        kpis: {
          browser_pageviews: {
            value: 0,
          },
          logged_in_share: {
            value: 0,
          },
        },
        pageview_series: [
          { id: "logged_in", default_visible: true, data: [{ date: "2026-05-01", count: 0 }] },
          { id: "anonymous", default_visible: true, data: [{ date: "2026-05-01", count: 0 }] },
          { id: "crawlers", default_visible: false, data: [{ date: "2026-05-01", count: 0 }] },
        ],
      )

      SiteSetting.embed_topics_list = true
      Fabricate(:embeddable_host)

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-01")).to eq(
        kpis: {
          browser_pageviews: {
            value: 0,
          },
          logged_in_share: {
            value: 0,
          },
        },
        pageview_series: [
          { id: "logged_in", default_visible: true, data: [{ date: "2026-05-01", count: 0 }] },
          { id: "anonymous", default_visible: true, data: [{ date: "2026-05-01", count: 0 }] },
          { id: "embedded", default_visible: true, data: [{ date: "2026-05-01", count: 7 }] },
          { id: "crawlers", default_visible: false, data: [{ date: "2026-05-01", count: 0 }] },
        ],
      )
    end

    it "includes embedded traffic when full app embedding is enabled" do
      SiteSetting.embed_full_app = true

      Fabricate(:embeddable_host)
      Fabricate(:embedded_application_request, date: "2026-05-01", count: 7)

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-01")).to eq(
        kpis: {
          browser_pageviews: {
            value: 0,
          },
          logged_in_share: {
            value: 0,
          },
        },
        pageview_series: [
          { id: "logged_in", default_visible: true, data: [{ date: "2026-05-01", count: 0 }] },
          { id: "anonymous", default_visible: true, data: [{ date: "2026-05-01", count: 0 }] },
          { id: "embedded", default_visible: true, data: [{ date: "2026-05-01", count: 7 }] },
          { id: "crawlers", default_visible: false, data: [{ date: "2026-05-01", count: 0 }] },
        ],
      )
    end

    it "returns logged-in traffic only when login is required" do
      SiteSetting.login_required = true
      SiteSetting.embed_topics_list = true

      Fabricate(:embeddable_host)
      Fabricate(:logged_in_browser_application_request, date: "2026-05-01", count: 9)
      Fabricate(:anonymous_browser_application_request, date: "2026-05-01", count: 19)
      Fabricate(:crawler_application_request, date: "2026-05-01", count: 29)
      Fabricate(:embedded_application_request, date: "2026-05-01", count: 5)

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-01")).to eq(
        kpis: {
          browser_pageviews: {
            value: 9,
          },
        },
        pageview_series: [
          { id: "logged_in", default_visible: true, data: [{ date: "2026-05-01", count: 9 }] },
        ],
      )
    end

    it "omits trend data when the comparison period predates tracked human traffic" do
      Fabricate(:logged_in_browser_application_request, date: "2026-04-30", count: 2)

      Fabricate(:logged_in_browser_application_request, date: "2026-05-01", count: 8)

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-03")).to eq(
        kpis: {
          browser_pageviews: {
            value: 8,
          },
          logged_in_share: {
            value: 100,
          },
        },
        pageview_series: [
          {
            id: "logged_in",
            default_visible: true,
            data: [
              { date: "2026-05-01", count: 8 },
              { date: "2026-05-02", count: 0 },
              { date: "2026-05-03", count: 0 },
            ],
          },
          {
            id: "anonymous",
            default_visible: true,
            data: [
              { date: "2026-05-01", count: 0 },
              { date: "2026-05-02", count: 0 },
              { date: "2026-05-03", count: 0 },
            ],
          },
          {
            id: "crawlers",
            default_visible: false,
            data: [
              { date: "2026-05-01", count: 0 },
              { date: "2026-05-02", count: 0 },
              { date: "2026-05-03", count: 0 },
            ],
          },
        ],
      )
    end

    it "returns zero-value KPIs and series when no traffic has been recorded" do
      ApplicationRequest.delete_all

      expect(described_class.build(start_date: "2026-05-01", end_date: "2026-05-03")).to eq(
        kpis: {
          browser_pageviews: {
            value: 0,
          },
          logged_in_share: {
            value: 0,
          },
        },
        pageview_series: [
          {
            id: "logged_in",
            default_visible: true,
            data: [
              { date: "2026-05-01", count: 0 },
              { date: "2026-05-02", count: 0 },
              { date: "2026-05-03", count: 0 },
            ],
          },
          {
            id: "anonymous",
            default_visible: true,
            data: [
              { date: "2026-05-01", count: 0 },
              { date: "2026-05-02", count: 0 },
              { date: "2026-05-03", count: 0 },
            ],
          },
          {
            id: "crawlers",
            default_visible: false,
            data: [
              { date: "2026-05-01", count: 0 },
              { date: "2026-05-02", count: 0 },
              { date: "2026-05-03", count: 0 },
            ],
          },
        ],
      )
    end

    it "uses the default date range when dates are missing, malformed, or reversed" do
      Fabricate(:logged_in_browser_application_request, date: "2026-04-14", count: 3)

      response_summaries =
        [
          described_class.build(start_date: nil, end_date: nil),
          described_class.build(start_date: "not-a-date", end_date: "also-not-a-date"),
          described_class.build(start_date: "2026-05-10", end_date: "2026-05-01"),
        ].map do |response|
          logged_in_series =
            response[:pageview_series].find { |traffic_series| traffic_series[:id] == "logged_in" }

          {
            browser_pageviews: response.dig(:kpis, :browser_pageviews, :value),
            first_point: logged_in_series[:data].first,
            last_point: logged_in_series[:data].last,
            data_points: logged_in_series[:data].size,
          }
        end

      expect(response_summaries).to eq(
        [
          {
            browser_pageviews: 3,
            first_point: {
              date: "2026-04-14",
              count: 3,
            },
            last_point: {
              date: "2026-05-14",
              count: 0,
            },
            data_points: 31,
          },
          {
            browser_pageviews: 3,
            first_point: {
              date: "2026-04-14",
              count: 3,
            },
            last_point: {
              date: "2026-05-14",
              count: 0,
            },
            data_points: 31,
          },
          {
            browser_pageviews: 3,
            first_point: {
              date: "2026-04-14",
              count: 3,
            },
            last_point: {
              date: "2026-05-14",
              count: 0,
            },
            data_points: 31,
          },
        ],
      )
    end
  end
end
