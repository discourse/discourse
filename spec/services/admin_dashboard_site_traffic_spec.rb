# frozen_string_literal: true

RSpec.describe AdminDashboardSiteTraffic do
  fab!(:admin)

  before do
    freeze_time(Time.zone.local(2026, 5, 14, 12, 0, 0))
    SiteSetting.use_legacy_pageviews = false
    SiteSetting.persist_browser_pageview_events = false
  end

  def build_traffic(start_date: nil, end_date: nil, guardian: admin.guardian)
    described_class.build(start_date: start_date, end_date: end_date, guardian: guardian)
  end

  def traffic_point(date, count)
    { x: date, y: count }
  end

  def traffic_series(id, data, req: traffic_series_req(id))
    canonical_req = traffic_series_req(id)

    {
      req: req,
      label: I18n.t("reports.site_traffic.xaxis.#{canonical_req}"),
      color: Reports::SiteTraffic::SERIES_COLORS.fetch(canonical_req),
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

      expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-03")).to eq(
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

      expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-03")).to eq(
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

    it "returns daily rows for longer selected date ranges" do
      Fabricate(:logged_in_browser_application_request, date: "2026-02-28", count: 99)

      Fabricate(:logged_in_browser_application_request, date: "2026-03-01", count: 1)
      Fabricate(:logged_in_browser_application_request, date: "2026-03-07", count: 2)
      Fabricate(:logged_in_browser_application_request, date: "2026-03-08", count: 4)
      Fabricate(:logged_in_browser_application_request, date: "2026-04-04", count: 8)
      Fabricate(:anonymous_browser_application_request, date: "2026-03-08", count: 10)

      response = build_traffic(start_date: "2026-03-01", end_date: "2026-04-04")

      dates = (Date.iso8601("2026-03-01")..Date.iso8601("2026-04-04")).map(&:iso8601)
      logged_in_counts = {
        "2026-03-01" => 1,
        "2026-03-07" => 2,
        "2026-03-08" => 4,
        "2026-04-04" => 8,
      }
      anonymous_counts = { "2026-03-08" => 10 }

      expect(traffic_series_data(response, :logged_in)).to eq(
        dates.map { |date| traffic_point(date, logged_in_counts.fetch(date, 0)) },
      )
      expect(traffic_series_data(response, :anonymous)).to eq(
        dates.map { |date| traffic_point(date, anonymous_counts.fetch(date, 0)) },
      )
    end

    it "omits trend data when the comparison period has no pageviews" do
      Fabricate(:logged_in_browser_application_request, date: "2026-04-01", count: 1)

      Fabricate(:logged_in_browser_application_request, date: "2026-05-01", count: 8)

      expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-03")[:kpis]).to eq(
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

      expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-03")[:kpis]).to eq(
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

      expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-03")[:kpis]).to eq(
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

      expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-03")[:kpis]).to eq(
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

      expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-03")[:kpis]).to eq(
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

      expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-01")).to eq(
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

      expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-01")).to eq(
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

      expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-01")).to eq(
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

      expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-01")).to eq(
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

      expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-01")).to eq(
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

      expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-01")).to eq(
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

      expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-03")).to eq(
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

      expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-03")).to eq(
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
      Fabricate(:logged_in_browser_application_request, date: "2026-04-15", count: 3)

      response_summaries =
        [
          build_traffic(start_date: nil, end_date: nil),
          build_traffic(start_date: "not-a-date", end_date: "also-not-a-date"),
          build_traffic(start_date: "2026-05-10", end_date: "2026-05-01"),
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
            first_point: traffic_point("2026-04-15", 3),
            last_point: traffic_point("2026-05-14", 0),
            data_points: 30,
          },
          {
            browser_pageviews: 3,
            first_point: traffic_point("2026-04-15", 3),
            last_point: traffic_point("2026-05-14", 0),
            data_points: 30,
          },
          {
            browser_pageviews: 3,
            first_point: traffic_point("2026-04-15", 3),
            last_point: traffic_point("2026-05-14", 0),
            data_points: 30,
          },
        ],
      )
    end

    context "for top countries and top referrers" do
      before { SiteSetting.persist_browser_pageview_events = true }

      def aggregate_rollups
        range = { start_date: 1.year.ago.to_date, end_date: Date.current }
        BrowserPageviewCountryDailyRollup.aggregate(**range)
        BrowserPageviewReferrerDailyRollup.aggregate(**range)
      end

      it "omits top_countries and top_referrers when persist_browser_pageview_events is disabled" do
        SiteSetting.persist_browser_pageview_events = false

        result = build_traffic(start_date: nil, end_date: nil)
        expect(result).not_to have_key(:top_countries)
        expect(result).not_to have_key(:top_referrers)
      end

      it "returns top_countries and top_referrers with rows and no error when matching events exist" do
        6.times do
          Fabricate(:browser_pageview_event, country_code: "US", normalized_referrer: "google.com")
        end
        aggregate_rollups

        result = build_traffic(start_date: nil, end_date: nil)

        expect(result[:top_countries][:rows].first[:country_code]).to eq("US")
        expect(result[:top_countries][:error]).to be_nil

        expect(result[:top_referrers][:rows].first[:normalized_referrer]).to eq("google.com")
        expect(result[:top_referrers][:error]).to be_nil
      end

      it "caps each card at the top 5 rows on both the fresh and cached paths" do
        %w[US GB DE FR JP CA].each do |code|
          Fabricate(
            :browser_pageview_event,
            country_code: code,
            normalized_referrer: "#{code.downcase}.example.com",
          )
        end
        aggregate_rollups

        fresh = build_traffic(start_date: nil, end_date: nil)
        expect(fresh[:top_countries][:rows].size).to eq(5)
        expect(fresh[:top_referrers][:rows].size).to eq(5)

        cached = build_traffic(start_date: nil, end_date: nil)
        expect(cached[:top_countries][:rows].size).to eq(5)
        expect(cached[:top_referrers][:rows].size).to eq(5)
      end

      it "returns empty rows when no events match the date range" do
        result = build_traffic(start_date: nil, end_date: nil)
        expect(result[:top_countries]).to eq(rows: [], error: nil)
        expect(result[:top_referrers]).to eq(rows: [], error: nil)
      end

      it "returns an exception error payload when the underlying report cannot be built" do
        allow(Report).to receive(:find).and_return(nil)

        result = build_traffic(start_date: nil, end_date: nil)
        expect(result[:top_countries]).to eq(rows: [], error: "exception")
        expect(result[:top_referrers]).to eq(rows: [], error: "exception")
      end

      it "serves the cached payload on subsequent calls within the cache window" do
        4.times do
          Fabricate(:browser_pageview_event, country_code: "US", normalized_referrer: "google.com")
        end
        aggregate_rollups

        first = build_traffic(start_date: nil, end_date: nil)
        expect(first[:top_countries][:rows].first[:country_code]).to eq("US")

        BrowserPageviewCountryDailyRollup.delete_all
        BrowserPageviewReferrerDailyRollup.delete_all
        BrowserPageviewEvent.delete_all

        second = build_traffic(start_date: nil, end_date: nil)
        expect(second[:top_countries][:rows].first[:country_code]).to eq("US")
        expect(second[:top_countries][:rows].first.keys).to all(be_a(Symbol))
      end

      it "invalidates the cached payload when login_required is toggled" do
        4.times do
          Fabricate(:browser_pageview_event, country_code: "US", normalized_referrer: "google.com")
        end
        aggregate_rollups

        SiteSetting.login_required = false
        first = build_traffic(start_date: nil, end_date: nil)
        expect(first[:top_countries][:rows].first[:country_code]).to eq("US")

        SiteSetting.login_required = true
        second = build_traffic(start_date: nil, end_date: nil)
        expect(second[:top_countries][:rows]).to be_empty
      end

      it "invalidates the cached payload when current_hostname changes" do
        Discourse.stubs(:current_hostname).returns("forum-a.example.com")
        Fabricate(:browser_pageview_event, normalized_referrer: "forum-b.example.com/path")
        aggregate_rollups

        first = build_traffic(start_date: nil, end_date: nil)
        expect(first[:top_referrers][:rows].first[:normalized_referrer]).to eq(
          "forum-b.example.com/path",
        )

        Discourse.stubs(:current_hostname).returns("forum-b.example.com")
        second = build_traffic(start_date: nil, end_date: nil)
        expect(second[:top_referrers][:rows]).to be_empty
      end

      it "serves the cached error payload on subsequent calls" do
        allow(Report).to receive(:find) do |type, opts|
          Report
            ._get(type, opts)
            .tap do |report|
              report.error = :exception
              report.data = []
            end
        end

        first = build_traffic(start_date: nil, end_date: nil)
        expect(first[:top_countries]).to eq(rows: [], error: "exception")

        allow(Report).to receive(:find).and_call_original

        second = build_traffic(start_date: nil, end_date: nil)
        expect(second[:top_countries]).to eq(rows: [], error: "exception")
      end

      it "returns a timeout error payload and retries the report on a subsequent call" do
        allow(Report).to receive(:find) do |type, _opts|
          Report
            .new(type)
            .tap do |report|
              report.error = :timeout
              report.data = []
            end
        end

        first = build_traffic(start_date: nil, end_date: nil)
        expect(first[:top_countries]).to eq(rows: [], error: "timeout")
        expect(first[:top_referrers]).to eq(rows: [], error: "timeout")

        allow(Report).to receive(:find).and_call_original
        Fabricate(:browser_pageview_event, country_code: "US", normalized_referrer: "google.com")
        aggregate_rollups

        second = build_traffic(start_date: nil, end_date: nil)
        expect(second[:top_countries][:rows].first[:country_code]).to eq("US")
      end
    end

    context "for direct traffic share" do
      before { SiteSetting.persist_browser_pageview_events = true }

      def aggregate_referrer_rollups
        BrowserPageviewReferrerDailyRollup.aggregate(
          start_date: "2026-05-01".to_date,
          end_date: "2026-05-01".to_date,
        )
      end

      it "returns the rounded share of pageviews that arrived with no referrer" do
        3.times do
          Fabricate(:browser_pageview_event, normalized_referrer: nil, created_at: "2026-05-01")
        end
        9.times do
          Fabricate(
            :browser_pageview_event,
            normalized_referrer: "google.com",
            created_at: "2026-05-01",
          )
        end
        aggregate_referrer_rollups

        expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-03")[:kpis]).to eq(
          browser_pageviews: {
            value: 0,
          },
          logged_in_share: {
            value: 0,
          },
          direct_traffic: {
            value: 25,
          },
        )
      end

      it "reports zero direct traffic when every tracked pageview had a referrer" do
        4.times do
          Fabricate(
            :browser_pageview_event,
            normalized_referrer: "google.com",
            created_at: "2026-05-01",
          )
        end
        aggregate_referrer_rollups

        expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-03")[:kpis]).to eq(
          browser_pageviews: {
            value: 0,
          },
          logged_in_share: {
            value: 0,
          },
          direct_traffic: {
            value: 0,
          },
        )
      end

      it "computes the share from logged-in pageviews only when login is required" do
        SiteSetting.login_required = true
        member = Fabricate(:user)

        Fabricate(
          :browser_pageview_event,
          normalized_referrer: nil,
          user_id: member.id,
          created_at: "2026-05-01",
        )
        Fabricate(
          :browser_pageview_event,
          normalized_referrer: nil,
          user_id: nil,
          created_at: "2026-05-01",
        )
        2.times do
          Fabricate(
            :browser_pageview_event,
            normalized_referrer: "google.com",
            user_id: member.id,
            created_at: "2026-05-01",
          )
        end
        aggregate_referrer_rollups

        expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-03")[:kpis]).to eq(
          browser_pageviews: {
            value: 0,
          },
          direct_traffic: {
            value: 33,
          },
        )
      end

      it "omits direct traffic when persist_browser_pageview_events is disabled" do
        SiteSetting.persist_browser_pageview_events = false

        3.times do
          Fabricate(:browser_pageview_event, normalized_referrer: nil, created_at: "2026-05-01")
        end
        aggregate_referrer_rollups

        expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-03")[:kpis]).to eq(
          browser_pageviews: {
            value: 0,
          },
          logged_in_share: {
            value: 0,
          },
        )
      end

      it "omits direct traffic when no pageviews were tracked in the period" do
        expect(build_traffic(start_date: "2026-05-01", end_date: "2026-05-03")[:kpis]).to eq(
          browser_pageviews: {
            value: 0,
          },
          logged_in_share: {
            value: 0,
          },
        )
      end
    end
  end
end
