# frozen_string_literal: true

describe "Admin Dashboard Redesign | Site Traffic section" do
  fab!(:current_user, :admin)

  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }

  before do
    SiteSetting.dashboard_improvements = true
    AdminDashboardSectionConfiguration.update(
      [
        { id: "traffic", visible: true },
        { id: "highlights", visible: false },
        { id: "reports", visible: false },
        { id: "engagement", visible: false },
      ],
      actor: current_user,
    )
    SiteSetting.use_legacy_pageviews = false
    SiteSetting.embed_topics_list = true
    sign_in(current_user)
  end

  it "lets staff review pageview totals, inspect tooltips, and compare another period",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    Fabricate(:embeddable_host)

    Fabricate(:logged_in_browser_application_request, date: "2025-11-18", count: 25)
    Fabricate(:logged_in_browser_application_request, date: "2026-03-16", count: 5)

    Fabricate(:logged_in_browser_application_request, date: "2026-05-01", count: 15)
    Fabricate(:logged_in_browser_application_request, date: "2026-05-12", count: 20)
    Fabricate(:anonymous_browser_application_request, date: "2026-05-12", count: 10)
    Fabricate(:crawler_application_request, date: "2026-05-12", count: 5)
    Fabricate(:embedded_application_request, date: "2026-05-12", count: 3)

    dashboard.visit
    expect(dashboard).to have_section("traffic")

    traffic = dashboard.site_traffic

    expect(traffic).to have_headline("45 pageviews in the last 30 days")
    expect(traffic).to have_up_trend("up 800%")
    expect(traffic).to have_metric("Logged-in share", "78%")

    traffic.hover_comparison_tooltip
    expect(traffic).to have_comparison_tooltip(
      "Compared with the previous 30 days (Mar 16 – Apr 14, 2026)",
    )

    traffic.hover_logged_in_share_tooltip
    expect(traffic).to have_logged_in_share_tooltip(
      "The share of pageviews from logged-in members.",
    )

    dashboard.select_preset("last_7_days")

    expect(traffic).to have_headline("30 pageviews in the last 7 days")
    expect(traffic).to have_trend("up 100%")

    traffic.hover_comparison_tooltip
    expect(traffic).to have_comparison_tooltip(
      "Compared with the previous 7 days (May 1 – May 7, 2026)",
    )

    dashboard.select_preset("last_3_months")

    expect(traffic).to have_headline("50 pageviews in the last 3 months")
    expect(traffic).to have_trend("up 100%")

    traffic.hover_comparison_tooltip
    expect(traffic).to have_comparison_tooltip(
      "Compared with the previous 3 months (Nov 18, 2025 – Feb 14, 2026)",
    )
  end

  it "shows staff when pageviews are down compared with the previous period",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    Fabricate(:logged_in_browser_application_request, date: "2026-03-16", count: 80)

    Fabricate(:logged_in_browser_application_request, date: "2026-05-12", count: 20)

    dashboard.visit
    traffic = dashboard.site_traffic

    expect(traffic).to have_headline("20 pageviews in the last 30 days")
    expect(traffic).to have_down_trend("down 75%")
  end

  it "shows staff traffic for a selected custom date range",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    Fabricate(:logged_in_browser_application_request, date: "2026-04-28", count: 10)

    Fabricate(:logged_in_browser_application_request, date: "2026-05-01", count: 20)

    dashboard.visit_with_query(range: "custom", start_date: "2026-05-01", end_date: "2026-05-03")
    traffic = dashboard.site_traffic

    expect(traffic).to have_headline("20 pageviews in the selected period")
    expect(traffic).to have_trend("up 100%")

    traffic.hover_comparison_tooltip
    expect(traffic).to have_comparison_tooltip(
      "Compared with the previous 3 days (Apr 28 – Apr 30, 2026)",
    )
  end

  it "shows staff login-required pageviews without logged-in share",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    SiteSetting.login_required = true

    Fabricate(:embeddable_host)
    Fabricate(:logged_in_browser_application_request, date: "2026-05-12", count: 9)
    Fabricate(:anonymous_browser_application_request, date: "2026-05-12", count: 19)

    Fabricate(:crawler_application_request, date: "2026-05-12", count: 29)
    Fabricate(:embedded_application_request, date: "2026-05-12", count: 5)

    dashboard.visit
    traffic = dashboard.site_traffic

    expect(traffic).to have_headline("9 pageviews in the last 30 days")
    expect(traffic).to have_no_metric("Logged-in share")
  end

  it "shows staff a zero-value traffic chart when no pageviews were recorded",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    ApplicationRequest.delete_all

    dashboard.visit
    traffic = dashboard.site_traffic

    expect(traffic).to have_headline("0 pageviews in the last 30 days")
    expect(traffic).to have_no_trend
    expect(traffic).to have_no_comparison_tooltip
    expect(traffic).to have_chart
  end

  it "takes staff to the full site traffic report scoped to the same period when they click See details",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    Fabricate(:logged_in_browser_application_request, date: "2026-05-05", count: 10)

    dashboard.visit_with_query(range: "custom", start_date: "2026-05-01", end_date: "2026-05-12")
    traffic = dashboard.site_traffic

    expect(traffic).to have_chart
    expect(traffic).to have_see_details_link

    traffic.click_see_details

    expect(page).to have_current_path(
      "/admin/reports/site_traffic?end_date=2026-05-12&start_date=2026-05-01",
    )
  end

  context "with top countries and top referrers cards" do
    let(:browser_pageview_source) { BrowserPageviewEvent::SOURCE_BEACON }

    before do
      SiteSetting.persist_browser_pageview_events = true
      UpcomingChangeEvent.create!(
        upcoming_change_name: "dashboard_improvements",
        event_type: :manual_opt_in,
        created_at: Time.zone.local(2026, 4, 30, 9),
      )
      Discourse.stubs(:current_hostname).returns("test.localhost")
      Discourse.cache.clear
    end

    it "does not show the cards when persist_browser_pageview_events is off" do
      SiteSetting.persist_browser_pageview_events = false

      dashboard.visit
      traffic = dashboard.site_traffic

      expect(traffic).to have_no_top_countries_card
      expect(traffic).to have_no_top_referrers_card
      expect(traffic).to have_no_metric("Direct traffic")
    end

    it "shows ranked top countries and top referrers when events exist in the period",
       time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
      2.times do
        Fabricate(
          :browser_pageview_event,
          country_code: "US",
          normalized_referrer: "news.ycombinator.com/item?id=42",
          created_at: "2026-05-12",
          source: browser_pageview_source,
        )
      end
      Fabricate(
        :browser_pageview_event,
        country_code: "GB",
        normalized_referrer: "reddit.com/r/discourse",
        created_at: "2026-05-12",
        source: browser_pageview_source,
      )
      Fabricate(
        :browser_pageview_event,
        country_code: "DE",
        normalized_referrer: nil,
        created_at: "2026-05-12",
        source: browser_pageview_source,
      )
      # Internal-referrer and direct (no-referrer) pageviews must not dilute the
      # top referrers percent denominator (it counts external referrer traffic only).
      6.times do
        Fabricate(
          :browser_pageview_event,
          country_code: "DE",
          normalized_referrer: "test.localhost/t/topic/1",
          created_at: "2026-05-12",
          source: browser_pageview_source,
        )
      end

      BrowserPageviewCountryDailyRollup.aggregate(
        start_date: "2026-05-01".to_date,
        end_date: "2026-05-14".to_date,
      )
      BrowserPageviewReferrerDailyRollup.aggregate(
        start_date: "2026-05-01".to_date,
        end_date: "2026-05-14".to_date,
      )

      dashboard.visit
      traffic = dashboard.site_traffic

      expect(traffic).to have_top_country_rows(
        [
          { country: "DE", percent: 70 },
          { country: "US", percent: 20 },
          { country: "GB", percent: 10 },
        ],
      )
      expect(traffic).to have_top_referrer_rows(
        [
          { referrer: "news.ycombinator.com/item?id=42", percent: 67 },
          { referrer: "reddit.com/r/discourse", percent: 33 },
        ],
      )

      expect(traffic).to have_metric("Direct traffic", "10%")

      traffic.hover_direct_traffic_tooltip
      expect(traffic).to have_direct_traffic_tooltip(
        "The share of pageviews that came directly to your community, such as by typing your URL or using a browser bookmark.",
      )
    end

    it "shows an empty state in both cards but keeps the headers as drill-down links when no events qualify",
       time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
      dashboard.visit
      traffic = dashboard.site_traffic

      expect(traffic).to have_top_countries_empty_state
      expect(traffic).to have_top_referrers_empty_state
      expect(traffic).to have_top_referrers_drilldown
      expect(traffic).to have_top_countries_drilldown
      expect(traffic).to have_no_metric("Direct traffic")
    end

    it "drills into the full top referrers report scoped to the dashboard period",
       time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
      Fabricate(
        :browser_pageview_event,
        normalized_referrer: "news.ycombinator.com/item?id=42",
        created_at: "2026-05-12",
        source: browser_pageview_source,
      )
      BrowserPageviewReferrerDailyRollup.aggregate(
        start_date: "2026-05-01".to_date,
        end_date: "2026-05-14".to_date,
      )

      dashboard.visit_with_query(range: "custom", start_date: "2026-05-01", end_date: "2026-05-12")
      dashboard.site_traffic.click_top_referrers_drilldown

      expect(page).to have_current_path(
        "/admin/reports/top_referrers_by_browser_pageviews?end_date=2026-05-12&start_date=2026-05-01",
      )
    end

    it "drills into the full top countries report scoped to the dashboard period",
       time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
      Fabricate(
        :browser_pageview_event,
        country_code: "US",
        created_at: "2026-05-12",
        source: browser_pageview_source,
      )
      BrowserPageviewCountryDailyRollup.aggregate(
        start_date: "2026-05-01".to_date,
        end_date: "2026-05-14".to_date,
      )

      dashboard.visit_with_query(range: "custom", start_date: "2026-05-01", end_date: "2026-05-12")
      dashboard.site_traffic.click_top_countries_drilldown

      expect(page).to have_current_path(
        "/admin/reports/top_countries_by_browser_pageviews?end_date=2026-05-12&start_date=2026-05-01",
      )
    end
  end

  context "with bounce rate and average session duration metrics" do
    before { SiteSetting.persist_browser_pageview_events = true }

    it "shows staff the bounce rate and average session duration for the period",
       time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
      Fabricate(
        :browser_pageview_session_engagement_daily_rollup,
        date: Date.new(2026, 5, 12),
        logged_in: false,
        sessions: 8,
        bounced: 3,
        engaged_seconds_total: 480,
      )
      Fabricate(
        :browser_pageview_session_engagement_daily_rollup,
        date: Date.new(2026, 5, 12),
        logged_in: true,
        sessions: 12,
        bounced: 2,
        engaged_seconds_total: 720,
      )

      dashboard.visit
      traffic = dashboard.site_traffic

      expect(traffic).to have_bounce_rate("25%")
      expect(traffic).to have_average_session_duration("1m 0s")
    end

    it "shows staff a placeholder and tooltip when no visits fall in the period",
       time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
      dashboard.visit
      traffic = dashboard.site_traffic

      expect(traffic).to have_bounce_rate("—")
      expect(traffic).to have_average_session_duration("—")

      traffic.hover_bounce_rate_tooltip
      expect(traffic).to have_session_metric_tooltip(
        "Shown once visits are recorded for this period.",
      )
    end

    it "does not show the metric tiles when persist_browser_pageview_events is off",
       time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
      SiteSetting.persist_browser_pageview_events = false
      Fabricate(
        :browser_pageview_session_engagement_daily_rollup,
        date: Date.new(2026, 5, 12),
        logged_in: false,
        sessions: 8,
        bounced: 3,
        engaged_seconds_total: 480,
      )

      dashboard.visit
      traffic = dashboard.site_traffic

      expect(traffic).to have_no_bounce_rate
      expect(traffic).to have_no_average_session_duration
    end
  end
end
