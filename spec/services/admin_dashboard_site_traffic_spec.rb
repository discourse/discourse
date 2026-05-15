# frozen_string_literal: true

RSpec.describe AdminDashboardSiteTraffic do
  before do
    freeze_time(Time.zone.local(2026, 5, 14, 12, 0, 0))
    SiteSetting.use_legacy_pageviews = false
  end

  def traffic_point(date, count, end_date: nil)
    point = { x: date, y: count }
    point[:end_date] = end_date if end_date
    point
  end

  def traffic_series(id, data, req: traffic_series_req(id))
    {
      req: req,
      label: I18n.t("reports.site_traffic.xaxis.#{traffic_series_label_req(id)}"),
      color_var: "--db-traffic-series-#{id.to_s.tr("_", "-")}-color",
      data: data,
    }
  end

  def traffic_series_req(id)
    {
      logged_in: "page_view_logged_in_browser",
      anonymous: "page_view_anon_browser",
      embedded: "page_view_embed",
      crawlers: "page_view_crawler",
    }.fetch(id)
  end

  def traffic_series_label_req(id)
    {
      logged_in: "page_view_logged_in_browser",
      anonymous: "page_view_anon_browser",
      embedded: "page_view_embed",
      crawlers: "page_view_crawler",
    }.fetch(id)
  end

  def traffic_series_data(response, id, req: traffic_series_req(id))
    response[:pageview_series].find { |traffic_series| traffic_series[:req] == req }[:data]
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
          traffic_series(
            :logged_in,
            [
              traffic_point("2026-05-01", 10),
              traffic_point("2026-05-02", 0),
              traffic_point("2026-05-03", 0),
            ],
          ),
          traffic_series(
            :anonymous,
            [
              traffic_point("2026-05-01", 0),
              traffic_point("2026-05-02", 20),
              traffic_point("2026-05-03", 0),
            ],
          ),
          traffic_series(
            :embedded,
            [
              traffic_point("2026-05-01", 0),
              traffic_point("2026-05-02", 4),
              traffic_point("2026-05-03", 0),
            ],
          ),
          traffic_series(
            :crawlers,
            [
              traffic_point("2026-05-01", 0),
              traffic_point("2026-05-02", 0),
              traffic_point("2026-05-03", 3),
            ],
          ),
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
          traffic_series(
            :logged_in,
            [
              traffic_point("2026-05-01", 5),
              traffic_point("2026-05-02", 0),
              traffic_point("2026-05-03", 0),
            ],
          ),
          traffic_series(
            :anonymous,
            [
              traffic_point("2026-05-01", 0),
              traffic_point("2026-05-02", 0),
              traffic_point("2026-05-03", 0),
            ],
          ),
          traffic_series(
            :crawlers,
            [
              traffic_point("2026-05-01", 0),
              traffic_point("2026-05-02", 0),
              traffic_point("2026-05-03", 0),
            ],
          ),
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

      expect(traffic_series_data(response, :logged_in)).to eq(
        [
          traffic_point("2026-03-01", 3, end_date: "2026-03-07"),
          traffic_point("2026-03-08", 4, end_date: "2026-03-14"),
          traffic_point("2026-03-15", 0, end_date: "2026-03-21"),
          traffic_point("2026-03-22", 0, end_date: "2026-03-28"),
          traffic_point("2026-03-29", 8, end_date: "2026-04-04"),
        ],
      )
      expect(traffic_series_data(response, :anonymous)).to eq(
        [
          traffic_point("2026-03-01", 0, end_date: "2026-03-07"),
          traffic_point("2026-03-08", 10, end_date: "2026-03-14"),
          traffic_point("2026-03-15", 0, end_date: "2026-03-21"),
          traffic_point("2026-03-22", 0, end_date: "2026-03-28"),
          traffic_point("2026-03-29", 0, end_date: "2026-04-04"),
        ],
      )
    end

    it "returns monthly buckets for year-long selected date ranges" do
      Fabricate(:logged_in_browser_application_request, date: "2025-01-01", count: 1)
      Fabricate(:logged_in_browser_application_request, date: "2025-01-31", count: 2)
      Fabricate(:logged_in_browser_application_request, date: "2025-02-01", count: 4)
      Fabricate(:logged_in_browser_application_request, date: "2025-12-31", count: 8)

      response = described_class.build(start_date: "2025-01-01", end_date: "2025-12-31")

      expect(traffic_series_data(response, :logged_in)).to eq(
        [
          traffic_point("2025-01-01", 3, end_date: "2025-01-31"),
          traffic_point("2025-02-01", 4, end_date: "2025-02-28"),
          traffic_point("2025-03-01", 0, end_date: "2025-03-31"),
          traffic_point("2025-04-01", 0, end_date: "2025-04-30"),
          traffic_point("2025-05-01", 0, end_date: "2025-05-31"),
          traffic_point("2025-06-01", 0, end_date: "2025-06-30"),
          traffic_point("2025-07-01", 0, end_date: "2025-07-31"),
          traffic_point("2025-08-01", 0, end_date: "2025-08-31"),
          traffic_point("2025-09-01", 0, end_date: "2025-09-30"),
          traffic_point("2025-10-01", 0, end_date: "2025-10-31"),
          traffic_point("2025-11-01", 0, end_date: "2025-11-30"),
          traffic_point("2025-12-01", 8, end_date: "2025-12-31"),
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
          traffic_series(:logged_in, [traffic_point("2026-05-01", 10)]),
          traffic_series(:anonymous, [traffic_point("2026-05-01", 20)]),
          traffic_series(:crawlers, [traffic_point("2026-05-01", 0)]),
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
          traffic_series(:logged_in, [traffic_point("2026-05-01", 11)], req: "page_view_logged_in"),
          traffic_series(:anonymous, [traffic_point("2026-05-01", 22)], req: "page_view_anon"),
          traffic_series(:crawlers, [traffic_point("2026-05-01", 4)]),
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
          traffic_series(:logged_in, [traffic_point("2026-05-01", 0)]),
          traffic_series(:anonymous, [traffic_point("2026-05-01", 0)]),
          traffic_series(:crawlers, [traffic_point("2026-05-01", 0)]),
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
          traffic_series(:logged_in, [traffic_point("2026-05-01", 0)]),
          traffic_series(:anonymous, [traffic_point("2026-05-01", 0)]),
          traffic_series(:embedded, [traffic_point("2026-05-01", 7)]),
          traffic_series(:crawlers, [traffic_point("2026-05-01", 0)]),
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
          traffic_series(:logged_in, [traffic_point("2026-05-01", 0)]),
          traffic_series(:anonymous, [traffic_point("2026-05-01", 0)]),
          traffic_series(:embedded, [traffic_point("2026-05-01", 7)]),
          traffic_series(:crawlers, [traffic_point("2026-05-01", 0)]),
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
        pageview_series: [traffic_series(:logged_in, [traffic_point("2026-05-01", 9)])],
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
          traffic_series(
            :logged_in,
            [
              traffic_point("2026-05-01", 8),
              traffic_point("2026-05-02", 0),
              traffic_point("2026-05-03", 0),
            ],
          ),
          traffic_series(
            :anonymous,
            [
              traffic_point("2026-05-01", 0),
              traffic_point("2026-05-02", 0),
              traffic_point("2026-05-03", 0),
            ],
          ),
          traffic_series(
            :crawlers,
            [
              traffic_point("2026-05-01", 0),
              traffic_point("2026-05-02", 0),
              traffic_point("2026-05-03", 0),
            ],
          ),
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
          traffic_series(
            :logged_in,
            [
              traffic_point("2026-05-01", 0),
              traffic_point("2026-05-02", 0),
              traffic_point("2026-05-03", 0),
            ],
          ),
          traffic_series(
            :anonymous,
            [
              traffic_point("2026-05-01", 0),
              traffic_point("2026-05-02", 0),
              traffic_point("2026-05-03", 0),
            ],
          ),
          traffic_series(
            :crawlers,
            [
              traffic_point("2026-05-01", 0),
              traffic_point("2026-05-02", 0),
              traffic_point("2026-05-03", 0),
            ],
          ),
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
          logged_in_series_data = traffic_series_data(response, :logged_in)

          {
            browser_pageviews: response.dig(:kpis, :browser_pageviews, :value),
            first_point: logged_in_series_data.first,
            last_point: logged_in_series_data.last,
            data_points: logged_in_series_data.size,
          }
        end

      expect(response_summaries).to eq(
        [
          {
            browser_pageviews: 3,
            first_point: traffic_point("2026-04-14", 3),
            last_point: traffic_point("2026-05-14", 0),
            data_points: 31,
          },
          {
            browser_pageviews: 3,
            first_point: traffic_point("2026-04-14", 3),
            last_point: traffic_point("2026-05-14", 0),
            data_points: 31,
          },
          {
            browser_pageviews: 3,
            first_point: traffic_point("2026-04-14", 3),
            last_point: traffic_point("2026-05-14", 0),
            data_points: 31,
          },
        ],
      )
    end
  end
end
