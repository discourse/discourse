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
    expect(traffic).to have_grouped_filter_pill(
      dimension: "traffic_type",
      label: "Traffic type is Logged in or Anonymous",
    )
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
    expect(traffic).to have_grouped_filter_pill(
      dimension: "traffic_type",
      label: "Traffic type is Logged in or Anonymous",
    )
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
    traffic.filter_by_clicking_row(card: "pages", label: "/latest")
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

    additional_paths = []
    9.times do |index|
      topic = Fabricate(:topic, title: "Traffic topic #{index}")
      path = "/t/#{topic.slug}/#{topic.id}"
      additional_paths << path if index >= 7
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
    traffic.select_filter_row(card: "visitors", label: "Unknown browser")

    traffic.expand("pages")

    expect(traffic).to have_expanded_table(title: "Top URLs", column: "URL")
    additional_paths.each { |path| expect(traffic).to have_expanded_url_link(label: path) }

    additional_paths.each { |path| traffic.select_expanded_filter_row(label: path) }

    expect(traffic).to have_expanded_table(title: "Top URLs", column: "URL")
    expect(traffic).to have_metric(label: "Pageviews", value: "45")
    traffic.apply_expanded_filters

    expect(traffic).to have_grouped_filter_pill(
      dimension: "top_url",
      label: "Top URL is #{additional_paths.first} or #{additional_paths.second}",
    )
    expect(traffic).to have_filter_pill(dimension: "browser", label: "Unknown browser")
    expect(traffic).to have_no_expanded_table
    expect(traffic).to have_apply_filters(count: 3)
    expect(traffic).to have_metric(label: "Pageviews", value: "45")
    traffic.apply_filters

    expect(traffic).to have_no_apply_filters
    expect(traffic).to have_metric(label: "Pageviews", value: "3")
    expected_path =
      "/admin/dashboard/site-traffic-explorer?browser=unknown&end_date=2026-05-12&" \
        "range=custom&start_date=2026-05-01&" \
        "top_url=#{ERB::Util.url_encode(additional_paths.to_json)}"
    expect(page).to have_current_path(expected_path)
  end

  it "lets an admin review and apply several filter values together",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    sign_in(admin)

    [
      %w[/first one.example US first-session],
      %w[/second two.example US second-session],
      %w[/third one.example GB third-session],
      ["/fourth", nil, "US", "fourth-session"],
      %w[/fifth three.example US fifth-session],
    ].each do |url, normalized_referrer, country_code, session_id|
      Fabricate(
        :browser_pageview_event,
        url: url,
        country_code: country_code,
        ip_address: country_code == "US" ? "192.0.2.1" : "198.51.100.2",
        normalized_referrer: normalized_referrer,
        normalized_referrer_version: BrowserPageviewEventUrlNormalizer::REFERRER_VERSION,
        session_id: session_id,
        source: BrowserPageviewEvent::SOURCE_BEACON,
        created_at: "2026-05-10 10:00:00",
      )
    end

    traffic.visit(start_date: "2026-05-01", end_date: "2026-05-12")

    traffic.select_filter_row(card: "acquisition", label: "one.example")
    traffic.select_filter_row(card: "acquisition", label: "two.example")
    traffic.select_filter_row(card: "acquisition", label: "three.example")
    traffic.select_tab(card: "acquisition", tab: "Countries")
    traffic.select_filter_row(card: "acquisition", label: "United States")

    expect(traffic).to have_grouped_filter_pill(
      dimension: "referrer",
      label: "Referrer is one.example or two.example or three.example",
    )
    expect(traffic).to have_filter_pill(dimension: "country", label: "United States")
    expect(traffic).to have_apply_filters(count: 4)
    expect(traffic).to have_metric(label: "Pageviews", value: "5")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?end_date=2026-05-12&range=custom&start_date=2026-05-01",
    )
    traffic.expand_filter_pill("referrer")

    expect(traffic).to have_filter_dropdown(values: %w[one.example two.example three.example])
    traffic.remove_filter_value("three.example")

    expect(traffic).to have_filter_dropdown(values: %w[one.example two.example])

    traffic.select_tab(card: "acquisition", tab: "Referrers")

    expect(traffic).to have_filter_row_selected(card: "acquisition", label: "one.example")
    expect(traffic).to have_filter_row_unselected(card: "acquisition", label: "three.example")

    traffic.select_filter_row(card: "acquisition", label: "three.example")
    traffic.apply_filters

    expect(traffic).to have_grouped_filter_pill(
      dimension: "referrer",
      label: "Referrer is one.example or two.example or three.example",
    )
    expect(traffic).to have_no_apply_filters
    expect(traffic).to have_metric(label: "Pageviews", value: "3")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?country=US&end_date=2026-05-12&range=custom&referrer=%5B%22one.example%22%2C%22two.example%22%2C%22three.example%22%5D&start_date=2026-05-01",
    )

    page.refresh

    expect(traffic).to have_grouped_filter_pill(
      dimension: "referrer",
      label: "Referrer is one.example or two.example or three.example",
    )
    expect(traffic).to have_filter_pill(dimension: "country", label: "United States")
    expect(traffic).to have_metric(label: "Pageviews", value: "3")

    traffic.clear_all_filters

    expect(traffic).to have_no_filter_pills
    expect(traffic).to have_metric(label: "Pageviews", value: "5")
    expect(page).to have_current_path(
      "/admin/dashboard/site-traffic-explorer?end_date=2026-05-12&range=custom&start_date=2026-05-01",
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
