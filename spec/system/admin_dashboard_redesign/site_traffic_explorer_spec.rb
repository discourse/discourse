# frozen_string_literal: true

RSpec.describe "Admin Dashboard Redesign | Site Traffic Explorer" do
  fab!(:admin)

  let(:traffic) { PageObjects::Pages::AdminSiteTrafficExplorer.new }

  before do
    SiteSetting.dashboard_improvements = true
    SiteSetting.improved_crawler_detection = true
    SiteSetting.persist_browser_pageview_events = true
    SiteSetting.use_legacy_pageviews = false
    BrowserPageviewEvent.stubs(:beacon_cutover_date).returns(Date.new(2026, 1, 1))
    Discourse.stubs(:current_hostname).returns("test.localhost")
    DiscourseIpInfo
      .stubs(:get)
      .with { |_ip, **options| options[:resolve_hostname] != false }
      .returns({})
    DiscourseIpInfo
      .stubs(:get)
      .with { |ip, **options| ip.to_s == "192.0.2.1" && options[:resolve_hostname] == false }
      .returns(
        country_code: "US",
        country: "United States",
        asn: 64_496,
        organization: "Example Network",
      )
    DiscourseIpInfo
      .stubs(:get)
      .with { |ip, **options| ip.to_s == "198.51.100.2" && options[:resolve_hostname] == false }
      .returns(
        country_code: "GB",
        country: "United Kingdom",
        asn: 64_497,
        organization: "Example Network",
      )
    DiscourseIpInfo
      .stubs(:get)
      .with { |ip, **options| ip.to_s == "203.0.113.3" && options[:resolve_hostname] == false }
      .returns(
        country_code: "US",
        country: "United States",
        asn: 64_498,
        organization: "Example Network",
      )
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

  it "lets an admin see session KPIs formed from available raw pageviews",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    sign_in(admin)

    Fabricate(
      :browser_pageview_event,
      url: "/engaged-session",
      session_id: "engaged-session",
      source: BrowserPageviewEvent::SOURCE_BEACON,
      created_at: "2026-05-14 10:00:00",
    )
    Fabricate(
      :browser_pageview_session_engagement,
      session_id: "engaged-session",
      engaged_seconds: 20,
    )
    Fabricate(
      :browser_pageview_event,
      url: "/active-session",
      session_id: "active-session",
      source: BrowserPageviewEvent::SOURCE_BEACON,
      created_at: "2026-05-14 11:50:00",
    )
    Fabricate(
      :browser_pageview_session_engagement,
      session_id: "active-session",
      engaged_seconds: 0,
    )

    traffic.visit(start_date: "2026-05-14", end_date: "2026-05-14")

    expect(traffic).to have_metric(label: "Pageviews", value: "2")
    expect(traffic).to have_metric(label: "Distinct sessions", value: "2")
    expect(traffic).to have_metric(label: "Bounce rate", value: "50%")
    expect(traffic).to have_metric(label: "Average session duration", value: "10s")
  end

  it "lets an admin investigate traffic with dates and filters",
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
        normalized_referrer: "search.example/results?q=discourse",
        normalized_referrer_version: BrowserPageviewEventUrlNormalizer::REFERRER_VERSION,
        created_at: "2026-05-10 10:00:00",
      },
      {
        url: "https://test.localhost/top?sort=popular",
        country_code: "US",
        asn: 64_496,
        ip_address: "192.0.2.1",
        user_agent: chrome,
        user_id: admin.id,
        session_id: "logged-in-session",
        normalized_referrer: "test.localhost/latest",
        normalized_referrer_version: BrowserPageviewEventUrlNormalizer::REFERRER_VERSION,
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
    expect(traffic).to have_metric(label: "Pageviews", value: "4")
    expect(traffic).to have_metric(label: "Distinct sessions", value: "3")
    expect(traffic).to have_metric(label: "Logged-in share", value: "50%")
    expect(traffic).to have_metric(label: "Bounce rate", value: "67%")
    expect(traffic).to have_metric(label: "Average session duration", value: "20s")
    expect(traffic).to have_series_total(label: "logged-in-human", value: "2")
    expect(traffic).to have_series_total(label: "anonymous-human", value: "1")
    expect(traffic).to have_series_total(label: "likely-crawler", value: "1")
    expect(traffic).to have_no_partial_data_warning

    traffic.visit(
      start_date: "2026-05-01",
      end_date: "2026-05-12",
      traffic_type: "logged_in,anonymous",
    )
    expect(traffic).to have_filter_pill(dimension: "traffic_type", label: "Logged in")
    expect(traffic).to have_filter_pill(dimension: "traffic_type", label: "Anonymous")
    expect(traffic).to have_metric(label: "Pageviews", value: "3")
    expect(traffic).to have_metric(label: "Distinct sessions", value: "2")
    expect(traffic).to have_series_total(label: "logged-in-human", value: "2")
    expect(traffic).to have_series_total(label: "anonymous-human", value: "1")
    expect(traffic).to have_series_total(label: "likely-crawler", value: "0")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?end_date=2026-05-12&range=custom&start_date=2026-05-01&traffic_type=logged_in%2Canonymous",
    )

    traffic.go_back
    expect(traffic).to have_no_filter_pills
    expect(traffic).to have_metric(label: "Pageviews", value: "4")

    traffic.go_forward
    expect(traffic).to have_filter_pill(dimension: "traffic_type", label: "Logged in")
    expect(traffic).to have_filter_pill(dimension: "traffic_type", label: "Anonymous")
    expect(traffic).to have_metric(label: "Distinct sessions", value: "2")

    traffic.remove_filter("traffic_type", label: "Logged in")
    expect(traffic).to have_filter_pill(dimension: "traffic_type", label: "Anonymous")
    expect(traffic).to have_metric(label: "Pageviews", value: "1")

    traffic.remove_filter("traffic_type", label: "Anonymous")
    expect(traffic).to have_no_filter_pills
    expect(traffic).to have_metric(label: "Pageviews", value: "4")

    traffic.visit(start_date: "2026-05-01", end_date: "2026-05-12", traffic_type: "likely_crawler")
    expect(traffic).to have_filter_pill(dimension: "traffic_type", label: "Likely crawlers")
    expect(traffic).to have_metric(label: "Pageviews", value: "1")
    expect(traffic).to have_metric(label: "Distinct sessions", value: "1")
    expect(traffic).to have_series_total(label: "logged-in-human", value: "0")
    expect(traffic).to have_series_total(label: "anonymous-human", value: "0")
    expect(traffic).to have_series_total(label: "likely-crawler", value: "1")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?end_date=2026-05-12&range=custom&start_date=2026-05-01&traffic_type=likely_crawler",
    )
    traffic.remove_filter("traffic_type", label: "Likely crawlers")
    expect(traffic).to have_metric(label: "Pageviews", value: "4")

    expect(traffic).to have_card_tabs(card: "acquisition", tabs: %w[Referrers Countries Networks])
    expect(traffic).to have_card_tabs(card: "pages", tabs: ["Top URLs", "Entry URLs"])
    expect(traffic).to have_card_tabs(card: "visitors", tabs: ["Browsers", "IP addresses"])
    expect(traffic).to have_row(card: "acquisition", label: "Direct / unknown", count: "2")
    expect(traffic).to have_row(
      card: "acquisition",
      label: "search.example/results?q=discourse",
      count: "1",
    )
    expect(traffic).to have_row(card: "pages", label: "/top", count: "2")
    expect(traffic).to have_url_link(card: "pages", label: "/top", href: "/top")

    traffic.select_tab(card: "pages", tab: "Entry URLs")
    expect(traffic).to have_row(card: "pages", label: "/latest", count: "1")
    expect(traffic).to have_url_link(card: "pages", label: "/latest", href: "/latest")
    traffic.filter_row(card: "pages", label: "/latest")
    expect(traffic).to have_filter_pill(dimension: "entry_url", label: "/latest")
    expect(traffic).to have_metric(label: "Pageviews", value: "1")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?end_date=2026-05-12&entry_url=%2Flatest&range=custom&start_date=2026-05-01",
    )
    traffic.remove_filter("entry_url")

    traffic.filter_row(card: "acquisition", label: "Direct / unknown")
    expect(traffic).to have_filter_pill(dimension: "referrer", label: "Direct / unknown")
    expect(traffic).to have_metric(label: "Pageviews", value: "2")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?end_date=2026-05-12&range=custom&referrer=&start_date=2026-05-01",
    )
    traffic.remove_filter("referrer")

    traffic.filter_row(card: "acquisition", label: "search.example/results?q=discourse")
    expect(traffic).to have_filter_pill(
      dimension: "referrer",
      label: "search.example/results?q=discourse",
    )
    expect(traffic).to have_metric(label: "Pageviews", value: "1")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?end_date=2026-05-12&range=custom&referrer=search.example%2Fresults%3Fq%3Ddiscourse&start_date=2026-05-01",
    )
    traffic.remove_filter("referrer")

    traffic.select_tab(card: "acquisition", tab: "Networks")
    traffic.filter_row(card: "acquisition", label: "Example Network (AS64496)")
    expect(traffic).to have_filter_pill(dimension: "network", label: "Example Network (AS64496)")
    expect(traffic).to have_metric(label: "Pageviews", value: "2")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?end_date=2026-05-12&network=AS64496&range=custom&start_date=2026-05-01",
    )
    traffic.remove_filter("network")

    traffic.select_tab(card: "visitors", tab: "Browsers")
    traffic.filter_row(card: "visitors", label: "Google Chrome")
    expect(traffic).to have_filter_pill(dimension: "browser", label: "Google Chrome")
    expect(traffic).to have_metric(label: "Pageviews", value: "3")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?browser=chrome&end_date=2026-05-12&range=custom&start_date=2026-05-01",
    )
    traffic.remove_filter("browser")

    traffic.select_tab(card: "acquisition", tab: "Countries")
    traffic.filter_row(card: "acquisition", label: "United States")
    expect(traffic).to have_filter_pill(dimension: "country", label: "United States")
    expect(traffic).to have_metric(label: "Pageviews", value: "3")
    expect(traffic).to have_metric(label: "Logged-in share", value: "67%")
    expect(traffic).to have_metric(label: "Distinct sessions", value: "2")
    expect(traffic).to have_metric(label: "Bounce rate", value: "50%")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?country=US&end_date=2026-05-12&range=custom&start_date=2026-05-01",
    )

    traffic.remove_filter("country")
    expect(traffic).to have_metric(label: "Pageviews", value: "4")
    traffic.select_tab(card: "acquisition", tab: "Countries")
    traffic.filter_row(card: "acquisition", label: "United Kingdom")
    expect(traffic).to have_filter_pill(dimension: "country", label: "United Kingdom")
    expect(traffic).to have_metric(label: "Pageviews", value: "1")

    traffic.remove_filter("country")
    expect(traffic).to have_metric(label: "Pageviews", value: "4")
    traffic.select_tab(card: "acquisition", tab: "Countries")
    traffic.filter_row(card: "acquisition", label: "United States")
    expect(traffic).to have_filter_pill(dimension: "country", label: "United States")

    traffic.select_tab(card: "pages", tab: "Top URLs")
    traffic.filter_row(card: "pages", label: "/top")
    expect(traffic).to have_filter_pill(dimension: "country", label: "United States")
    expect(traffic).to have_filter_pill(dimension: "top_url", label: "/top")
    expect(traffic).to have_metric(label: "Pageviews", value: "1")
    expect(traffic).to have_metric(label: "Distinct sessions", value: "1")
    expect(traffic).to have_metric(label: "Bounce rate", value: "0%")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?country=US&end_date=2026-05-12&range=custom&start_date=2026-05-01&top_url=%2Ftop",
    )

    traffic.select_tab(card: "visitors", tab: "IP addresses")
    traffic.filter_row(card: "visitors", label: "192.0.2.1")
    expect(traffic).to have_filter_pill(dimension: "ip", label: "192.0.2.1")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?country=US&end_date=2026-05-12&ip=192.0.2.1&range=custom&start_date=2026-05-01&top_url=%2Ftop",
    )

    page.refresh

    expect(traffic).to have_filter_pill(dimension: "country", label: "United States")
    expect(traffic).to have_filter_pill(dimension: "top_url", label: "/top")
    expect(traffic).to have_filter_pill(dimension: "ip", label: "192.0.2.1")
    expect(traffic).to have_metric(label: "Pageviews", value: "1")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?country=US&end_date=2026-05-12&ip=192.0.2.1&range=custom&start_date=2026-05-01&top_url=%2Ftop",
    )

    traffic.remove_filter("country")
    traffic.remove_filter("top_url")
    traffic.remove_filter("ip")

    expect(traffic).to have_no_filter_pills
    expect(traffic).to have_metric(label: "Pageviews", value: "4")

    traffic.select_date_preset("Last 7 days")

    expect(traffic).to have_date_range("Last 7 days")
    expect(page).to have_current_path("/admin/dashboard/site-traffic-explorer?range=last_7_days")

    traffic.select_custom_date_range(start_date: "2026-05-01", end_date: "2026-05-12")

    expect(traffic).to have_date_range("May 1, 2026 – May 12, 2026")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?end_date=2026-05-12&range=custom&start_date=2026-05-01",
    )
  end

  it "lets an admin filter additional results from an expanded table",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    sign_in(admin)

    additional_path = nil
    9.times do |index|
      topic = Fabricate(:topic, title: "Traffic topic #{index}")
      path = "/t/#{topic.slug}/#{topic.id}"
      additional_path = path if index == 8
      event_count = 9 - index
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

    traffic.expand("pages")

    expect(traffic).to have_expanded_table(title: "Top URLs", column: "URL")
    expect(traffic).to have_expanded_url_link(label: additional_path)

    traffic.filter_expanded_row(label: additional_path)

    expect(traffic).to have_filter_pill(dimension: "top_url", label: additional_path)
    expect(traffic).to have_no_expanded_table
  end

  it "lets an admin group and brush traffic into a precise local range",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0),
     timezone: "UTC" do
    sign_in(admin)

    9.times do |index|
      Fabricate(
        :browser_pageview_event,
        url: "/hourly-traffic",
        session_id: "hourly-session-#{index}",
        source: BrowserPageviewEvent::SOURCE_BEACON,
        created_at: Time.zone.local(2026, 5, 10, 10) + index * 15.minutes,
      )
    end

    traffic.visit_default

    expect(traffic).to have_date_range("Last 30 days")
    expect(traffic).to have_grouping("Automatic (day)")
    expect(traffic).to have_groupings("Automatic", "Hour", "Day")

    traffic.select_grouping("Hour")

    expect(traffic).to have_grouping("Hour")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?grouping=hour&range=last_30_days",
    )

    traffic.select_grouping("Automatic")

    expect(traffic).to have_grouping("Automatic (day)")
    expect(page).to have_current_path("/admin/dashboard/site-traffic-explorer?range=last_30_days")

    traffic.visit(start_date: "2026-05-10", end_date: "2026-05-11")

    expect(traffic).to have_grouping("Automatic (day)")

    traffic.select_grouping("Day")

    expect(traffic).to have_grouping("Day")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?end_date=2026-05-11&grouping=day&range=custom&start_date=2026-05-10",
    )

    traffic.select_grouping("Hour")

    expect(traffic).to have_grouping("Hour")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?end_date=2026-05-11&grouping=hour&range=custom&start_date=2026-05-10",
    )

    picker = traffic.open_date_picker
    expect(picker).to have_no_precision_mode
    expect(picker).to have_timezone("Times shown in UTC")
    expect(picker).to have_datetime_range(
      start_date: "2026-05-10",
      start_time: "00:00",
      end_date: "2026-05-11",
      end_time: "23:59",
    )
    picker.set_datetime_range(
      start_date: "2026-05-10",
      start_time: "10:00",
      end_date: "2026-05-10",
      end_time: "12:00",
    )
    picker.cancel

    expect(traffic).to have_date_range("May 10, 2026 – May 11, 2026")

    traffic.select_custom_datetime_range(
      start_date: "2026-05-10",
      start_time: "10:00",
      end_date: "2026-05-10",
      end_time: "12:00",
    )

    expect(traffic).to have_date_range("May 10, 2026, 10:00 AM – 12:00 PM UTC")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?end_at=2026-05-10T12%3A00%3A00Z&end_date=2026-05-10&grouping=hour&range=custom&start_at=2026-05-10T10%3A00%3A00Z&start_date=2026-05-10",
    )

    traffic.hover_chart(fraction: 0.5)
    expect(traffic).to have_hover_marker(
      fraction: 0.5,
      label: "May 10, 2026, 11:00 AM: tooltip point",
    )

    traffic.cancel_chart_drag(from: 0.25, to: 0.75)

    expect(traffic).to have_no_brush_selection
    expect(traffic).to have_date_range("May 10, 2026, 10:00 AM – 12:00 PM UTC")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?end_at=2026-05-10T12%3A00%3A00Z&end_date=2026-05-10&grouping=hour&range=custom&start_at=2026-05-10T10%3A00%3A00Z&start_date=2026-05-10",
    )

    traffic.drag_chart(from: 0.25, to: 0.75) do
      expect(traffic).to have_brush_selection
      expect(traffic).to have_live_brush_range("May 10, 2026, 10:30 AM – 11:30 AM UTC")
    end

    expect(traffic).to have_date_range("May 10, 2026, 10:30 AM – 11:30 AM UTC")
    expect(traffic).to have_grouping("Hour")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?end_at=2026-05-10T11%3A30%3A00Z&end_date=2026-05-10&grouping=hour&range=custom&start_at=2026-05-10T10%3A30%3A00Z&start_date=2026-05-10",
    )

    page.refresh

    expect(traffic).to have_date_range("May 10, 2026, 10:30 AM – 11:30 AM UTC")
    expect(traffic).to have_grouping("Hour")

    picker = traffic.open_date_picker
    expect(picker).to have_datetime_range(
      start_date: "2026-05-10",
      start_time: "10:30",
      end_date: "2026-05-10",
      end_time: "11:30",
    )

    picker.set_datetime_range(
      start_date: "2026-05-10",
      start_time: "00:00",
      end_date: "2026-05-10",
      end_time: "23:59",
    )
    picker.apply

    expect(traffic).to have_date_range("May 10, 2026")
    expect(traffic).to have_grouping("Hour")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?end_date=2026-05-10&grouping=hour&range=custom&start_date=2026-05-10",
    )
  end

  it "warns an admin when the selected range has incomplete traffic data",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0),
     timezone: "UTC" do
    sign_in(admin)
    SiteSetting.site_traffic_explorer_event_limit = 2

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
        "Results include the most recent 2 pageviews, beginning May 10, 2026 at 10:00 AM. Earlier pageviews in the selected date range are not included; pageview data before Feb 14, 2026 is no longer available.",
    )
  end

  it "tells an admin when no pageviews match" do
    sign_in(admin)

    traffic.visit(start_date: "2026-05-01", end_date: "2026-05-12")

    expect(traffic).to have_empty_state
  end
end
