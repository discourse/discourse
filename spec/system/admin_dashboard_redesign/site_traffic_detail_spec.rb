# frozen_string_literal: true

RSpec.describe "Admin Dashboard Redesign | Site traffic details" do
  fab!(:admin)

  let(:traffic) { PageObjects::Pages::AdminSiteTraffic.new }

  before do
    SiteSetting.dashboard_improvements = true
    SiteSetting.persist_browser_pageview_events = true
    SiteSetting.use_legacy_pageviews = false
    Discourse.cache.clear
    sign_in(admin)
  end

  def traffic_payload(pageviews:, filters:, countries: [], browsers: [])
    {
      analysis: {
        requested_start_date: "2026-05-01",
        requested_end_date: "2026-05-12",
        available_start_at: "2026-05-01T10:00:00Z",
        available_end_at: "2026-05-12T10:00:00Z",
        analyzed_start_at: "2026-05-01T10:00:00Z",
        analyzed_end_at: "2026-05-12T10:00:00Z",
        analyzed_event_count: 5,
        event_cap: 1_000_000,
        retention_truncated: false,
        cap_truncated: false,
        capture_scope: "retained_browser_pageviews",
        crawler_classification: "likely_crawler_score",
        crawler_scoring_state: "disabled",
        crawler_score_threshold: CrawlerScorer::BOT_SCORE_THRESHOLD,
        unscored_event_count: 5,
        session_scope: "capped_base_unfiltered",
      },
      filters: filters,
      summary: {
        pageviews: pageviews,
        logged_in_human_pageviews: 0,
        anonymous_human_pageviews: pageviews,
        likely_crawler_pageviews: 0,
        distinct_sessions: 5,
        bounce_rate: 100,
        average_session_duration_seconds: 0,
      },
      series: [],
      dimensions: {
        top_urls: [],
        entry_urls: [],
        traffic_sources: [],
        countries: countries,
        networks: [],
        browsers: browsers,
        ip_addresses: [],
      },
    }
  end

  it "lets an admin investigate retained pageviews without changing overall session metrics",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    topic = Fabricate(:topic, title: "Public traffic investigation topic")
    chrome =
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
        "AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36"
    firefox = "Mozilla/5.0 Firefox/126.0"

    [
      {
        url: "/landing?campaign=private",
        country_code: "US",
        ip_address: "192.0.2.1",
        user_agent: chrome,
        user_id: admin.id,
        session_id: "logged-in-session",
        referrer: "https://search.example/results?q=private",
        normalized_referrer: "search.example/results?q=private",
        normalized_referrer_version: BrowserPageviewReferrerInspector::VERSION,
        created_at: "2026-05-10 10:00:00",
      },
      {
        url: "/popular?token=private",
        country_code: "US",
        ip_address: "192.0.2.1",
        user_agent: chrome,
        user_id: admin.id,
        session_id: "logged-in-session",
        referrer: "https://test.localhost/landing",
        normalized_referrer: "test.localhost/landing",
        normalized_referrer_version: BrowserPageviewReferrerInspector::VERSION,
        created_at: "2026-05-10 10:01:00",
      },
      {
        url: "/popular",
        country_code: "US",
        ip_address: "192.0.2.1",
        user_agent: chrome,
        user_id: admin.id,
        session_id: "logged-in-session",
        created_at: "2026-05-10 10:02:00",
      },
      {
        url: "/other",
        country_code: "GB",
        ip_address: "198.51.100.2",
        user_agent: chrome,
        session_id: "crawler-session",
        score: CrawlerScorer::BOT_SCORE_THRESHOLD,
        created_at: "2026-05-11 10:00:00",
      },
      {
        url: "/t/public-topic/#{topic.id}",
        topic_id: topic.id,
        country_code: "CA",
        ip_address: "203.0.113.3",
        user_agent: firefox,
        session_id: "anonymous-session",
        created_at: "2026-05-12 10:00:00",
      },
    ].each { |attributes| Fabricate(:browser_pageview_event, **attributes) }

    BrowserPageviewSessionEngagement.create!(
      session_id: "logged-in-session",
      engaged_seconds: 60,
    )
    BrowserPageviewSessionEngagement.create!(
      session_id: "crawler-session",
      engaged_seconds: 0,
    )
    BrowserPageviewSessionEngagement.create!(
      session_id: "anonymous-session",
      engaged_seconds: 0,
    )

    traffic.visit_with_range(start_date: "2026-05-01", end_date: "2026-05-12")

    expect(traffic).to have_page_title
    expect(traffic).to have_pageview_summary(
      total: "5",
      logged_in_human: "3",
      anonymous_human: "1",
      likely_crawler: "1",
    )
    expect(traffic).to have_session_summary(
      distinct_sessions: "3",
      bounce_rate: "67%",
      average_duration: "20s",
    )
    expect(traffic).to have_chart_series(
      series: {
        "logged-in-human" => "3",
        "anonymous-human" => "1",
        "likely-crawler" => "1",
      },
      points: {
        "2026-05-10" => %w[3 0 0],
        "2026-05-11" => %w[0 0 1],
        "2026-05-12" => %w[0 1 0],
      },
    )
    expect(traffic).to have_crawler_scope_disclosure
    expect(traffic).to have_session_scope_disclosure
    expect(traffic).to have_breakdown_row(title: "Top URLs", label: "/popular", pageviews: "2")
    expect(traffic).to have_breakdown_row(title: "Entry URLs", label: "/landing", pageviews: "1")
    expect(traffic).to have_breakdown_row(
      title: "Traffic Sources",
      label: "search.example",
      pageviews: "1",
    )
    expect(traffic).to have_no_partial_data_warning
    expect(traffic).to have_no_generic_analysis_copy

    traffic.click_breakdown_row(title: "Countries", label: "United States")

    expect(traffic).to have_filter_chip(dimension: "country", value: "United States")
    expect(traffic).to have_pageview_summary(
      total: "3",
      logged_in_human: "3",
      anonymous_human: "0",
      likely_crawler: "0",
    )
    expect(traffic).to have_session_summary(
      distinct_sessions: "3",
      bounce_rate: "67%",
      average_duration: "20s",
    )

    traffic.click_breakdown_row(title: "Top URLs", label: "/popular")

    expect(traffic).to have_filter_chip(dimension: "url", value: "/popular")
    expect(traffic).to have_pageview_summary(
      total: "2",
      logged_in_human: "2",
      anonymous_human: "0",
      likely_crawler: "0",
    )
    expect(traffic).to have_session_summary(
      distinct_sessions: "3",
      bounce_rate: "67%",
      average_duration: "20s",
    )

    history_length = traffic.browser_history_length
    traffic.click_breakdown_row(title: "IP addresses", label: "192.0.2.1")

    expect(traffic).to have_filter_chip(dimension: "ip", value: "192.0.2.1")
    expect(traffic.browser_history_length).to eq(history_length)

    page.refresh

    expect(traffic).to have_filter_chip(dimension: "ip", value: "192.0.2.1")
    expect(traffic).to have_no_sensitive_url_state?("192.0.2.1", "/popular")

    traffic.remove_filter("ip")
    traffic.click_breakdown_row(title: "Countries", label: "Canada")

    expect(traffic).to have_filter_chip(dimension: "country", value: "Canada")
    expect(traffic).to have_no_filter_chip("ip")
    expect(traffic).to have_pageview_summary(
      total: "0",
      logged_in_human: "0",
      anonymous_human: "0",
      likely_crawler: "0",
    )

    traffic.remove_filter("url")

    expect(traffic).to have_pageview_summary(
      total: "1",
      logged_in_human: "0",
      anonymous_human: "1",
      likely_crawler: "0",
    )

    page.refresh

    expect(traffic).to have_filter_chip(dimension: "country", value: "Canada")
    expect(traffic).to have_safe_shareable_state(country: "CA", browser: nil)
    expect(traffic).to have_no_sensitive_url_state?("192.0.2.1", "/popular")
  end

  it "keeps cards bounded and makes the expanded table accessible",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    9.times do |index|
      Fabricate(
        :browser_pageview_event,
        url: "/page-#{index}",
        session_id: "session-#{index}",
        created_at: Time.zone.local(2026, 5, 10, 10, index),
      )
    end

    traffic.visit_with_range(start_date: "2026-05-01", end_date: "2026-05-12")

    expect(traffic).to have_top_row_count(title: "Top URLs", count: 8)

    traffic.expand("Top URLs")

    expect(traffic).to have_expanded_table(title: "Top URLs", row_count: 9)
  end

  it "keeps the last success while loading and discards a superseded response",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    initial_payload =
      traffic_payload(
        pageviews: 5,
        filters: {},
        countries: [
          { value: "US", label: "United States", pageviews: 3, filterable: true },
        ],
        browsers: [
          { value: "firefox", label: "Firefox", pageviews: 1, filterable: true },
        ],
      )
    final_payload =
      traffic_payload(
        pageviews: 1,
        filters: {
          country: "US",
          browser: "firefox",
        },
      )

    page.driver.with_playwright_page do |playwright_page|
      playwright_page.add_init_script(
        script: <<~JS,
          const originalFetch = window.fetch.bind(window);
          window.__trafficRequests = [];
          window.__trafficPending = [];
          window.__resolveTraffic = (index, body) => {
            window.__trafficPending[index].resolve(
              new Response(JSON.stringify(body), {
                status: 200,
                headers: { "Content-Type": "application/json" },
              })
            );
          };
          window.fetch = (resource, options = {}) => {
            const url = typeof resource === "string" ? resource : resource.url;
            if (!url.includes("/admin/dashboard/traffic.json")) {
              return originalFetch(resource, options);
            }

            const request = {
              body: JSON.parse(options.body),
              aborted: false,
            };
            window.__trafficRequests.push(request);

            return new Promise((resolve, reject) => {
              window.__trafficPending.push({ resolve, reject });
              options.signal?.addEventListener("abort", () => {
                request.aborted = true;
                reject(new DOMException("Superseded", "AbortError"));
              });
            });
          };
        JS
      )

      traffic.visit_with_range(start_date: "2026-05-01", end_date: "2026-05-12")
      expect(traffic).to have_loading_state

      playwright_page.evaluate(
        "body => window.__resolveTraffic(0, body)",
        initial_payload,
      )
      expect(traffic).to have_pageview_summary(
        total: "5",
        logged_in_human: "0",
        anonymous_human: "5",
        likely_crawler: "0",
      )

      traffic.click_breakdown_row(title: "Countries", label: "United States")
      expect(traffic).to have_loading_state_with_previous_total(total: "5")

      traffic.click_breakdown_row(title: "Browsers", label: "Firefox")

      expect(page.evaluate_script("window.__trafficRequests[1].aborted")).to eq(true)

      playwright_page.evaluate(
        "body => window.__resolveTraffic(2, body)",
        final_payload,
      )
      expect(traffic).to have_pageview_summary(
        total: "1",
        logged_in_human: "0",
        anonymous_human: "1",
        likely_crawler: "0",
      )
    end
  end

  it "shows distinct accessible states and preserves the selected range on retry",
     time: Time.zone.local(2026, 5, 14, 12, 0, 0) do
    responses = [
      {
        status: 200,
        body: {
          analysis: {
            requested_start_date: "2026-01-01",
            requested_end_date: "2026-05-12",
            available_start_at: "2026-02-12T00:00:00Z",
            available_end_at: "2026-05-12T10:00:00Z",
            analyzed_start_at: "2026-05-12T09:00:00Z",
            analyzed_end_at: "2026-05-12T10:00:00Z",
            analyzed_event_count: 2,
            event_cap: 2,
            retention_truncated: true,
            cap_truncated: true,
            capture_scope: "retained_browser_pageviews",
            crawler_classification: "likely_crawler_score",
            crawler_scoring_state: "disabled",
            crawler_score_threshold: CrawlerScorer::BOT_SCORE_THRESHOLD,
            unscored_event_count: 1,
            session_scope: "capped_base_unfiltered",
          },
          filters: {},
          summary: {
            pageviews: 2,
            logged_in_human_pageviews: 1,
            anonymous_human_pageviews: 0,
            likely_crawler_pageviews: 1,
            distinct_sessions: 2,
            bounce_rate: 50,
            average_session_duration_seconds: 12,
          },
          series: [],
          dimensions: {
            top_urls: [],
            entry_urls: [],
            traffic_sources: [],
            countries: [],
            networks: [],
            browsers: [],
            ip_addresses: [],
          },
        },
      },
      {
        status: 503,
        body: { error_type: "timeout", retryable: true },
      },
      {
        status: 200,
        body: {
          analysis: {
            requested_start_date: "2026-01-01",
            requested_end_date: "2026-05-12",
            available_start_at: nil,
            available_end_at: nil,
            analyzed_start_at: nil,
            analyzed_end_at: nil,
            analyzed_event_count: 0,
            event_cap: 1_000_000,
            retention_truncated: false,
            cap_truncated: false,
            capture_scope: "retained_browser_pageviews",
            crawler_classification: "likely_crawler_score",
            crawler_scoring_state: "disabled",
            crawler_score_threshold: CrawlerScorer::BOT_SCORE_THRESHOLD,
            unscored_event_count: 0,
            session_scope: "capped_base_unfiltered",
          },
          filters: {},
          summary: {
            pageviews: 0,
            logged_in_human_pageviews: 0,
            anonymous_human_pageviews: 0,
            likely_crawler_pageviews: 0,
            distinct_sessions: 0,
            bounce_rate: nil,
            average_session_duration_seconds: nil,
          },
          series: [],
          dimensions: {
            top_urls: [],
            entry_urls: [],
            traffic_sources: [],
            countries: [],
            networks: [],
            browsers: [],
            ip_addresses: [],
          },
        },
      },
      {
        status: 429,
        body: { error_type: "rate_limited", retry_after_seconds: 30 },
      },
      {
        status: 400,
        body: { error_type: "invalid_request" },
      },
      {
        status: 500,
        body: { error_type: "unexpected", retryable: true },
      },
    ]
    pattern = %r{/admin/dashboard/traffic\.json}

    page.driver.with_playwright_page do |playwright_page|
      playwright_page.route(
        pattern,
        lambda do |route, _request|
          next_response = responses.shift
          route.fulfill(
            status: next_response[:status],
            content_type: "application/json",
            body: JSON.generate(next_response[:body]),
          )
        end,
      )

      traffic.visit_with_range(start_date: "2026-01-01", end_date: "2026-05-12")

      expect(traffic).to have_partial_data_warning(
        requested: "Jan 1 – May 12, 2026",
        available: "Feb 12 – May 12, 2026",
        analyzed: "May 12, 2026, 9:00 am – 10:00 am",
        analyzed_count: "2",
        event_cap: "2",
      )
      expect(traffic).to have_no_generic_analysis_copy

      page.refresh

      expect(traffic).to have_error_state(
        message: "Site traffic took too long to load.",
        retry_button: true,
        narrow_range: true,
      )

      traffic.choose_narrower_range
      expect(traffic).to have_date_range_controls

      traffic.retry

      expect(traffic).to have_empty_state
      expect(page).to have_current_path(
        "/admin/dashboard/traffic?end_date=2026-05-12&start_date=2026-01-01",
      )

      page.refresh
      expect(traffic).to have_error_state(
        message: "You’ve made too many Site traffic requests. Try again shortly.",
      )

      page.refresh
      expect(traffic).to have_error_state(
        message: "This Site traffic request is invalid.",
      )

      page.refresh
      expect(traffic).to have_error_state(
        message: "Site traffic couldn’t be loaded. Try again.",
        retry_button: true,
      )
    ensure
      playwright_page.unroute(pattern)
    end
  end
end
