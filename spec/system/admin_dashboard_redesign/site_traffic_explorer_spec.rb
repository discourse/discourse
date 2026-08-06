# frozen_string_literal: true

RSpec.describe "Admin Dashboard Redesign | Site Traffic Explorer" do
  fab!(:admin)
  fab!(:other_admin, :admin)
  fab!(:moderator)

  let(:traffic) { PageObjects::Pages::AdminSiteTrafficExplorer.new }

  before do
    SiteSetting.dashboard_improvements = true
    SiteSetting.improved_crawler_detection = true
    SiteSetting.persist_browser_pageview_events = true
    SiteSetting.use_legacy_pageviews = false
    Discourse.stubs(:current_hostname).returns("test.localhost")
    DiscourseIpInfo.stubs(:get).returns(asn: 64_496, organization: "Example Network")
  end

  it "lets an admin see anonymous traffic without a crawler series when detection is disabled",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    SiteSetting.improved_crawler_detection = false
    sign_in(admin)

    Fabricate(
      :browser_pageview_event,
      url: "/crawler-shaped-traffic",
      session_id: "crawler-shaped-session",
      score: CrawlerScorer::BOT_SCORE_THRESHOLD + 1,
      source: BrowserPageviewEvent::SOURCE_BEACON,
      created_at: "2026-05-10 10:00:00",
    )

    traffic.visit(start_date: "2026-05-01", end_date: "2026-05-12")

    expect(traffic).to have_metric(label: "Pageviews", value: "1")
    expect(traffic).to have_series_total(label: "anonymous-human", value: "1")
    expect(traffic).to have_no_series(label: "likely-crawler")
  end

  it "lets an admin see session KPIs from completed sessions only",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    sign_in(admin)

    Fabricate(
      :browser_pageview_event,
      url: "/mature-session",
      session_id: "mature-session",
      source: BrowserPageviewEvent::SOURCE_BEACON,
      created_at: "2026-05-14 10:00:00",
    )
    Fabricate(
      :browser_pageview_session_engagement,
      session_id: "mature-session",
      engaged_seconds: 20,
    )
    Fabricate(
      :browser_pageview_event,
      url: "/unsettled-session",
      session_id: "unsettled-session",
      source: BrowserPageviewEvent::SOURCE_BEACON,
      created_at: "2026-05-14 11:50:00",
    )
    Fabricate(
      :browser_pageview_session_engagement,
      session_id: "unsettled-session",
      engaged_seconds: 0,
    )

    traffic.visit(start_date: "2026-05-14", end_date: "2026-05-14")

    expect(traffic).to have_metric(label: "Pageviews", value: "2")
    expect(traffic).to have_metric(label: "Distinct sessions", value: "1")
    expect(traffic).to have_metric(label: "Bounce rate", value: "0%")
    expect(traffic).to have_metric(label: "Average session duration", value: "20s")
  end

  it "lets an admin investigate pageviews with dashboard controls and row filters",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    sign_in(admin)

    chrome = "Mozilla/5.0 AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36"
    firefox = "Mozilla/5.0 Firefox/126.0"

    events = [
      {
        url: "https://test.localhost/latest/?campaign=secret#section",
        country_code: "US",
        asn: 64_496,
        ip_address: "192.0.2.1",
        user_agent: chrome,
        user_id: admin.id,
        session_id: "logged-in-session",
        normalized_referrer: "search.example/results?token=secret",
        normalized_referrer_version: BrowserPageviewReferrerInspector::VERSION,
        created_at: "2026-05-10 10:00:00",
      },
      {
        url: "https://test.localhost/top?token=secret",
        country_code: "US",
        asn: 64_496,
        ip_address: "192.0.2.1",
        user_agent: chrome,
        user_id: admin.id,
        session_id: "logged-in-session",
        normalized_referrer: "test.localhost/latest",
        normalized_referrer_version: BrowserPageviewReferrerInspector::VERSION,
        created_at: "2026-05-10 10:01:00",
      },
      {
        url: "/top",
        country_code: "GB",
        asn: 64_497,
        ip_address: "198.51.100.2",
        user_agent: firefox,
        session_id: "anonymous-session",
        created_at: "2026-05-11 10:00:00",
      },
      {
        url: "/hot",
        country_code: "US",
        asn: 64_498,
        ip_address: "203.0.113.3",
        user_agent: chrome,
        session_id: "crawler-session",
        score: CrawlerScorer::BOT_SCORE_THRESHOLD + 1,
        created_at: "2026-05-12 10:00:00",
      },
    ]
    events.each do |attributes|
      Fabricate(:browser_pageview_event, source: BrowserPageviewEvent::SOURCE_BEACON, **attributes)
    end

    Fabricate(
      :browser_pageview_session_engagement,
      session_id: "logged-in-session",
      engaged_seconds: 60,
    )
    Fabricate(
      :browser_pageview_session_engagement,
      session_id: "anonymous-session",
      engaged_seconds: 0,
    )
    Fabricate(
      :browser_pageview_session_engagement,
      session_id: "crawler-session",
      engaged_seconds: 0,
    )

    traffic.visit(start_date: "2026-05-01", end_date: "2026-05-12")

    expect(traffic).to have_page_title
    expect(traffic).to have_date_range("May 1, 2026 – May 12, 2026")
    expect(traffic).to have_no_filter_pills
    expect(traffic).to have_metric(label: "Pageviews", value: "3")
    expect(traffic).to have_metric(label: "Distinct sessions", value: "3")
    expect(traffic).to have_metric(label: "Logged-in share", value: "67%")
    expect(traffic).to have_metric(label: "Bounce rate", value: "67%")
    expect(traffic).to have_metric(label: "Average session duration", value: "20s")
    expect(traffic).to have_series_total(label: "logged-in-human", value: "2")
    expect(traffic).to have_series_total(label: "anonymous-human", value: "1")
    expect(traffic).to have_series_total(label: "likely-crawler", value: "1")
    expect(traffic).to have_no_partial_data_warning

    expect(traffic).to have_card_tabs(card: "acquisition", tabs: %w[Referrers Countries Networks])
    expect(traffic).to have_card_tabs(card: "pages", tabs: ["Top URLs", "Entry URLs"])
    expect(traffic).to have_card_tabs(card: "visitors", tabs: ["Browsers", "IP addresses"])
    expect(traffic).to have_row(card: "acquisition", label: "Direct / unknown", count: "2")
    expect(traffic).to have_row(card: "acquisition", label: "search.example", count: "1")
    expect(traffic).to have_row(card: "pages", label: "/top", count: "2")
    expect(traffic).to have_url_link(card: "pages", label: "/top", href: "/top")

    traffic.select_tab(card: "pages", tab: "Entry URLs")
    expect(traffic).to have_row(card: "pages", label: "/latest", count: "1")
    expect(traffic).to have_url_link(card: "pages", label: "/latest", href: "/latest")
    traffic.filter_row(card: "pages", label: "/latest")
    expect(traffic).to have_filter_pill(dimension: "entry_url", label: "/latest")
    expect(traffic).to have_metric(label: "Pageviews", value: "1")
    expect(page).to have_current_path(
      "/admin/dashboard/traffic?end_date=2026-05-12&range=custom&start_date=2026-05-01",
    )
    traffic.remove_filter("entry_url")

    traffic.filter_row(card: "acquisition", label: "Direct / unknown")
    expect(traffic).to have_filter_pill(dimension: "referrer", label: "Direct / unknown")
    expect(traffic).to have_metric(label: "Pageviews", value: "1")
    expect(page).to have_current_path(
      "/admin/dashboard/traffic?end_date=2026-05-12&range=custom&start_date=2026-05-01",
    )
    traffic.remove_filter("referrer")

    traffic.filter_row(card: "acquisition", label: "search.example")
    expect(traffic).to have_filter_pill(dimension: "referrer", label: "search.example")
    expect(traffic).to have_metric(label: "Pageviews", value: "1")
    expect(page).to have_current_path(
      "/admin/dashboard/traffic?end_date=2026-05-12&range=custom&start_date=2026-05-01",
    )
    traffic.remove_filter("referrer")

    traffic.select_tab(card: "acquisition", tab: "Networks")
    traffic.filter_row(card: "acquisition", label: "AS64496 Example Network")
    expect(traffic).to have_filter_pill(dimension: "network", label: "AS64496 Example Network")
    expect(traffic).to have_metric(label: "Pageviews", value: "2")
    expect(page).to have_current_path(
      "/admin/dashboard/traffic?end_date=2026-05-12&network=AS64496&range=custom&start_date=2026-05-01",
    )
    traffic.remove_filter("network")

    traffic.select_tab(card: "visitors", tab: "Browsers")
    traffic.filter_row(card: "visitors", label: "Chrome")
    expect(traffic).to have_filter_pill(dimension: "browser", label: "Chrome")
    expect(traffic).to have_metric(label: "Pageviews", value: "2")
    expect(page).to have_current_path(
      "/admin/dashboard/traffic?browser=chrome&end_date=2026-05-12&range=custom&start_date=2026-05-01",
    )
    traffic.remove_filter("browser")

    traffic.select_tab(card: "acquisition", tab: "Countries")
    traffic.filter_row(card: "acquisition", label: "United States")
    expect(traffic).to have_filter_pill(dimension: "country", label: "United States")
    expect(traffic).to have_metric(label: "Pageviews", value: "2")
    expect(traffic).to have_metric(label: "Logged-in share", value: "100%")
    expect(traffic).to have_metric(label: "Distinct sessions", value: "3")
    expect(traffic).to have_metric(label: "Bounce rate", value: "67%")
    expect(page).to have_current_path(
      "/admin/dashboard/traffic?country=US&end_date=2026-05-12&range=custom&start_date=2026-05-01",
    )

    traffic.remove_filter("country")
    traffic.filter_row(card: "acquisition", label: "United Kingdom")
    expect(traffic).to have_filter_pill(dimension: "country", label: "United Kingdom")
    expect(traffic).to have_metric(label: "Pageviews", value: "1")

    traffic.remove_filter("country")
    traffic.filter_row(card: "acquisition", label: "United States")
    expect(traffic).to have_filter_pill(dimension: "country", label: "United States")

    traffic.select_tab(card: "pages", tab: "Top URLs")
    traffic.filter_row(card: "pages", label: "/top")
    expect(traffic).to have_filter_pill(dimension: "country", label: "United States")
    expect(traffic).to have_filter_pill(dimension: "top_url", label: "/top")
    expect(traffic).to have_metric(label: "Pageviews", value: "1")
    expect(traffic).to have_metric(label: "Distinct sessions", value: "3")
    expect(traffic).to have_metric(label: "Bounce rate", value: "67%")
    expect(page).to have_current_path(
      "/admin/dashboard/traffic?country=US&end_date=2026-05-12&range=custom&start_date=2026-05-01",
    )

    traffic.select_tab(card: "visitors", tab: "IP addresses")
    traffic.filter_row(card: "visitors", label: "192.0.2.1")
    expect(traffic).to have_filter_pill(dimension: "ip", label: "192.0.2.1")
    expect(page).to have_current_path(
      "/admin/dashboard/traffic?country=US&end_date=2026-05-12&range=custom&start_date=2026-05-01",
    )

    page.refresh

    expect(traffic).to have_filter_pill(dimension: "country", label: "United States")
    expect(traffic).to have_filter_pill(dimension: "top_url", label: "/top")
    expect(traffic).to have_filter_pill(dimension: "ip", label: "192.0.2.1")
    expect(traffic).to have_metric(label: "Pageviews", value: "1")

    traffic.clear_filters

    expect(traffic).to have_no_filter_pills
    expect(traffic).to have_metric(label: "Pageviews", value: "3")

    traffic.select_date_preset("Last 30 days")

    expect(traffic).to have_date_range("Last 30 days")
    expect(page).to have_current_path("/admin/dashboard/traffic?range=last_30_days")
  end

  it "keeps sensitive filter values out of the page URL and other admin sessions" do
    Fabricate(
      :browser_pageview_event,
      url: "https://test.localhost/latest?secret=private",
      ip_address: "192.0.2.10",
      session_id: "sensitive-filter",
      source: BrowserPageviewEvent::SOURCE_BEACON,
      created_at: "2026-05-10 10:00:00",
    )

    sign_in(admin)
    traffic.visit(start_date: "2026-05-01", end_date: "2026-05-12")
    traffic.filter_row(card: "pages", label: "/latest")
    traffic.select_tab(card: "visitors", tab: "IP addresses")
    traffic.filter_row(card: "visitors", label: "192.0.2.10")

    expect(traffic).to have_filter_pill(dimension: "top_url", label: "/latest")
    expect(traffic).to have_filter_pill(dimension: "ip", label: "192.0.2.10")
    expect(page.current_url).not_to include("latest")
    expect(page.current_url).not_to include("192.0.2.10")

    page.refresh

    expect(traffic).to have_filter_pill(dimension: "top_url", label: "/latest")
    expect(traffic).to have_filter_pill(dimension: "ip", label: "192.0.2.10")

    sign_out
    sign_in(other_admin)
    traffic.visit(start_date: "2026-05-01", end_date: "2026-05-12")

    expect(traffic).to have_no_filter_pills

    Capybara.reset_session!
    sign_in(admin)
    traffic.visit(start_date: "2026-05-01", end_date: "2026-05-12")

    expect(traffic).to have_no_filter_pills
  end

  it "lets an admin expand eight-row cards to a table with at most 50 rows",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    sign_in(admin)

    ninth_path = nil
    51.times do |index|
      topic = Fabricate(:topic, title: "Traffic topic #{index}")
      path = "/t/#{topic.slug}/#{topic.id}"
      ninth_path = path if index == 8
      event_count = index < 9 ? 10 - index : 1
      event_count.times do |event_index|
        Fabricate(
          :browser_pageview_event,
          url: path,
          topic_id: topic.id,
          source: BrowserPageviewEvent::SOURCE_BEACON,
          created_at: Time.zone.local(2026, 5, 10, 10, index, event_index),
        )
      end
    end

    traffic.visit(start_date: "2026-05-01", end_date: "2026-05-12")

    expect(traffic).to have_top_row_count(card: "pages", count: 8)

    traffic.expand("pages")

    expect(traffic).to have_expanded_table(title: "Top URLs", row_count: 50)

    traffic.filter_expanded_row(label: ninth_path)

    expect(traffic).to have_filter_pill(dimension: "top_url", label: ninth_path)
    expect(traffic).to have_no_expanded_table
    expect(traffic).to have_focused_filter_pill(dimension: "top_url")
  end

  it "warns an admin when the selected range has incomplete traffic data",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    sign_in(admin)
    SiteSetting.clean_up_browser_pageview_events = true
    SiteSetting.stubs(:admin_site_traffic_event_cap).returns(2)

    [
      ["/first-retained", "2026-02-15 09:00:00"],
      ["/middle-retained", "2026-05-10 10:00:00"],
      ["/latest-retained", "2026-05-12 10:00:00"],
    ].each do |url, created_at|
      Fabricate(
        :browser_pageview_event,
        url: url,
        session_id: url.delete_prefix("/"),
        source: BrowserPageviewEvent::SOURCE_BEACON,
        created_at: created_at,
      )
    end

    traffic.visit(start_date: "2026-01-01", end_date: "2026-05-12")

    expect(traffic).to have_partial_data_warning(
      reason:
        "Traffic before Feb 14, 2026 is no longer available. These results are also limited to the most recent 2 pageviews in the selected date range. Choose a shorter date range within the available dates to include all available traffic.",
    )
  end

  it "keeps the explorer unavailable to a moderator" do
    sign_in(moderator)

    traffic.visit(start_date: "2026-05-01", end_date: "2026-05-12")

    expect(traffic).to have_not_found
  end

  it "tells an admin when no pageviews match" do
    sign_in(admin)

    traffic.visit(start_date: "2026-05-01", end_date: "2026-05-12")

    expect(traffic).to have_empty_state
  end
end
