# frozen_string_literal: true

describe "Admin Dashboard Redesign | Site Traffic section" do
  fab!(:current_user, :admin)
  fab!(:moderator)

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

  it "takes an admin to the traffic explorer with the selected period when they click See details" do
    SiteSetting.enable_site_traffic_explorer = true
    Fabricate(:logged_in_browser_application_request, date: "2026-05-05", count: 10)

    dashboard.visit_with_query(range: "custom", start_date: "2026-05-01", end_date: "2026-05-12")
    traffic = dashboard.site_traffic

    expect(traffic).to have_chart
    expect(traffic).to have_see_details_link

    traffic.click_see_details

    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?end_date=2026-05-12&range=custom&start_date=2026-05-01",
    )
  end

  it "links to the aggregate traffic report by default" do
    Fabricate(:logged_in_browser_application_request, date: "2026-05-05", count: 10)

    dashboard.visit_with_query(range: "custom", start_date: "2026-05-01", end_date: "2026-05-12")
    dashboard.site_traffic.click_see_details

    expect(page).to have_current_path(
      "/admin/reports/site_traffic?end_date=2026-05-12&start_date=2026-05-01",
    )
  end

  it "keeps the aggregate traffic report available to moderators" do
    SiteSetting.enable_site_traffic_explorer = true
    sign_in(moderator)

    dashboard.visit_with_query(range: "custom", start_date: "2026-05-01", end_date: "2026-05-12")
    dashboard.site_traffic.click_see_details

    expect(page).to have_current_path(
      "/admin/reports/site_traffic?end_date=2026-05-12&start_date=2026-05-01",
    )
  end

  context "with top countries, top referrers, and top entry URLs cards" do
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
      expect(traffic).to have_no_top_entry_urls_card
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

    it "lets admins identify the URLs that started the most browser entries in the selected period",
       time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
      topic = Fabricate(:topic, title: "A very viral topic")
      Fabricate(
        :browser_pageview_event,
        session_id: "viral-topic-visit-1",
        topic_id: topic.id,
        url: "https://test.localhost/t/viral-topic/#{topic.id}?utm_source=newsletter#post_1",
        created_at: "2026-05-12 10:00:00",
        source: browser_pageview_source,
      )
      Fabricate(
        :browser_pageview_event,
        session_id: "search-entry-visit",
        url: "https://test.localhost/search?q=private",
        created_at: "2026-05-12 10:05:00",
        source: browser_pageview_source,
      )
      Fabricate(
        :browser_pageview_event,
        session_id: "search-entry-visit",
        url: "https://test.localhost/t/should-not-count-after-search/98",
        referrer: "https://test.localhost/search?q=private",
        created_at: "2026-05-12 10:10:00",
        source: browser_pageview_source,
      )
      Fabricate(
        :browser_pageview_event,
        session_id: "viral-topic-visit-2",
        topic_id: topic.id,
        url: "https://test.localhost/t/viral-topic/#{topic.id}",
        created_at: "2026-05-12 11:00:00",
        source: browser_pageview_source,
      )
      Fabricate(
        :browser_pageview_event,
        session_id: "categories-visit",
        url: "https://test.localhost/categories",
        created_at: "2026-05-12 12:00:00",
        source: browser_pageview_source,
      )
      %w[faq guidelines new unread].each do |path|
        Fabricate(
          :browser_pageview_event,
          session_id: "#{path}-visit",
          url: "https://test.localhost/#{path}",
          created_at: "2026-05-12 12:30:00",
          source: browser_pageview_source,
        )
      end
      Fabricate(
        :browser_pageview_event,
        session_id: "cross-midnight-visit",
        url: "https://test.localhost/top",
        created_at: "2026-05-11 23:59:00",
        source: browser_pageview_source,
      )
      Fabricate(
        :browser_pageview_event,
        session_id: "cross-midnight-visit",
        url: "https://test.localhost/latest",
        referrer: "https://test.localhost/top",
        created_at: "2026-05-12 00:01:00",
        source: browser_pageview_source,
      )
      sensitive_entry_paths = %w[
        /associate/secret-token
        /email/unsubscribe/secret-key
        /session/email-login/secret-token
        /session/otp/deadbeef
        /u/activate-account/secret-token
        /u/confirm-email-token/secret-token
        /u/password-reset/secret-token
      ]
      sensitive_entry_paths.each_with_index do |path, index|
        Fabricate(
          :browser_pageview_event,
          session_id: "sensitive-path-visit-#{index}",
          url: "https://test.localhost#{path}",
          created_at: "2026-05-12 13:00:00",
          source: browser_pageview_source,
        )
        Fabricate(
          :browser_pageview_event,
          session_id: "sensitive-path-visit-#{index}",
          url: "https://test.localhost/t/should-not-count/#{index}",
          referrer: "https://test.localhost#{path}",
          created_at: "2026-05-12 13:05:00",
          source: browser_pageview_source,
        )
      end

      Jobs::MaintainBrowserPageviewRollups.new.execute({})

      dashboard.visit_with_query(range: "custom", start_date: "2026-05-12", end_date: "2026-05-12")
      traffic = dashboard.site_traffic

      expect(traffic).to have_top_entry_url_rows(
        [
          { path: "/t/#{topic.slug}/#{topic.id}", percent: 33, count: 2 },
          { path: "/categories", percent: 17, count: 1 },
          { path: "/faq", percent: 17, count: 1 },
          { path: "/guidelines", percent: 17, count: 1 },
          { path: "/new", percent: 17, count: 1 },
        ],
      )
      expect(traffic).to have_no_top_entry_url("/search")
      expect(traffic).to have_no_top_entry_url("/t/should-not-count-after-search/98")
      expect(traffic).to have_no_top_entry_url("/latest")
      expect(traffic).to have_no_top_entry_url("/unread")
      sensitive_entry_paths.each { |path| expect(traffic).to have_no_top_entry_url(path) }
      expect(traffic).to have_no_top_entry_url("/t/should-not-count")

      traffic.click_top_entry_urls_drilldown
      expect(page).to have_current_path(
        "/admin/reports/top_entry_urls?end_date=2026-05-12&start_date=2026-05-12",
      )
    end

    it "keeps entry URL analytics private from moderators",
       time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
      Fabricate(
        :browser_pageview_event,
        url: "https://test.localhost/t/private-analytics/1",
        created_at: "2026-05-12",
        source: browser_pageview_source,
      )
      Jobs::MaintainBrowserPageviewRollups.new.execute({})
      sign_in(Fabricate(:moderator))

      dashboard.visit

      expect(dashboard.site_traffic).to have_no_top_entry_urls_card
    end

    it "shows empty states but keeps the report headers as drill-down links when no events qualify",
       time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
      Fabricate(
        :browser_pageview_event,
        url: "https://test.localhost/latest",
        created_at: "2026-05-01",
        source: browser_pageview_source,
      )
      Jobs::MaintainBrowserPageviewRollups.new.execute({})

      dashboard.visit_with_query(range: "custom", start_date: "2026-05-02", end_date: "2026-05-14")
      traffic = dashboard.site_traffic

      expect(traffic).to have_top_countries_empty_state
      expect(traffic).to have_top_referrers_empty_state
      expect(traffic).to have_top_entry_urls_empty_state
      expect(traffic).to have_top_referrers_drilldown
      expect(traffic).to have_top_countries_drilldown
      expect(traffic).to have_top_entry_urls_drilldown
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
