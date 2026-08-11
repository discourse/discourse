import {
  click,
  currentURL,
  focus,
  settled,
  triggerEvent,
  triggerKeyEvent,
  visit,
  waitFor,
} from "@ember/test-helpers";
import { test } from "qunit";
import pretender from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

function response(pageviews = 40_000) {
  const row = { value: "US", label: "US", pageviews };

  return {
    partial_data: null,
    summary: {
      pageviews,
      distinct_sessions: pageviews,
      logged_in_share: 100,
      bounce_rate: pageviews === 1 ? 100 : 50,
      average_session_duration_seconds: pageviews === 1 ? 0 : 30,
    },
    series: [
      {
        date: "2026-05-10",
        pageviews,
        logged_in_human_pageviews: pageviews,
        anonymous_human_pageviews: 0,
        likely_crawler_pageviews: 0,
      },
    ],
    series_colors: {
      logged_in_human_pageviews: "#4B3CE0",
      anonymous_human_pageviews: "#9C8DEC",
      likely_crawler_pageviews: "#B3AAC9",
    },
    dimensions: {
      top_urls: [{ value: "/latest", label: "/latest", pageviews }],
      entry_urls: [{ value: "/latest", label: "/latest", pageviews: 1 }],
      referrers: [
        { value: "", label: "Direct / unknown", pageviews: 1 },
        {
          value: "search.example/results",
          label: "search.example/results",
          pageviews: 10_000,
        },
      ],
      countries: [row],
      networks: [
        { value: "AS64496", label: "Example Network (AS64496)", pageviews },
      ],
      browsers: [{ value: "chrome", label: "Chrome", pageviews }],
      ip_addresses: [{ value: "192.0.2.1", label: "192.0.2.1", pageviews }],
    },
  };
}

function crawlerOnlyResponse() {
  const traffic = response(0);
  traffic.series[0].likely_crawler_pageviews = 1;
  return traffic;
}

acceptance("Admin | Site Traffic Explorer", function (needs) {
  needs.user();
  needs.settings({
    dashboard_improvements: true,
    improved_crawler_detection: true,
  });
  needs.pretender((server, helper) => {
    server.get("/admin/dashboard/traffic.json", (request) => {
      const traffic = response(request.queryParams.country ? 10_000 : 40_000);
      if (request.queryParams.country) {
        traffic.active_filters = [
          { key: "country", value: "US", label: "United States" },
        ];
      }
      return helper.response(traffic);
    });
  });

  test("shows the response and applies a row filter", async function (assert) {
    await visit(
      "/admin/dashboard/traffic?end_date=2026-05-12&range=custom&start_date=2026-05-01"
    );

    assert.dom("h1").hasText("Site Traffic Explorer");
    assert
      .dom(
        "[data-test-site-traffic-metric='pageviews'] .site-traffic-explorer__metric-value"
      )
      .hasText("40K");
    await triggerEvent(
      "[data-test-site-traffic-metric='pageviews'] .fk-d-tooltip__trigger",
      "pointermove"
    );
    assert
      .dom(".fk-d-tooltip__content")
      .hasText("40,000", "shows the exact pageview count immediately");
    assert
      .dom("[data-test-site-traffic-card='visitors'] .d-icon-fab-chrome")
      .exists("shows a browser icon");
    assert
      .dom(
        "[data-test-site-traffic-card='acquisition'] .site-traffic-explorer__row-link"
      )
      .hasText("search.example/results")
      .hasAttribute("href", "https://search.example/results")
      .hasAttribute("target", "_blank")
      .hasAttribute(
        "rel",
        "noopener noreferrer nofollow ugc",
        "links the normalized referrer to its external destination"
      );

    const firstAcquisitionTab =
      "[data-test-site-traffic-card='acquisition'] [role='tab']:first-child";
    await focus(firstAcquisitionTab);
    await triggerKeyEvent(firstAcquisitionTab, "keydown", "ArrowRight");
    assert
      .dom(
        "[data-test-site-traffic-card='acquisition'] [role='tab']:nth-child(2)"
      )
      .isFocused()
      .hasAttribute("aria-selected", "true");
    assert
      .dom("[data-test-site-traffic-card='acquisition'] [role='tabpanel']")
      .includesText("🇺🇸 United States", "shows the full country name");
    assert
      .dom(
        "[data-test-site-traffic-card='acquisition'] .site-traffic-explorer__row-count"
      )
      .hasText("40K");
    await click(
      "[data-test-site-traffic-card='acquisition'] [data-test-site-traffic-row]"
    );

    assert
      .dom("[data-test-site-traffic-filter-pill='country']")
      .includesText("Country is United States");
    assert
      .dom("[data-test-site-traffic-filter-pill='country'] strong")
      .hasText("United States");
    assert
      .dom("[data-test-site-traffic-metric='pageviews']")
      .includesText("10K");
    assert
      .dom("[data-test-site-traffic-metric='distinct_sessions']")
      .includesText("10,000");
    assert.strictEqual(
      currentURL(),
      "/admin/dashboard/traffic?country=US&end_date=2026-05-12&range=custom&start_date=2026-05-01"
    );
  });
});

acceptance("Admin | Site Traffic Explorer | Loading", function (needs) {
  let pendingRequest;
  let resolvePendingRequest;

  needs.user();
  needs.settings({
    dashboard_improvements: true,
    improved_crawler_detection: true,
    page_loading_indicator: "spinner",
  });
  needs.pretender((_server, helper) => {
    pendingRequest = new Promise(
      (resolve) => (resolvePendingRequest = resolve)
    );
    pretender.get(
      "/admin/dashboard/traffic.json",
      (request) => {
        resolvePendingRequest(request);
        return helper.response(response());
      },
      true
    );
  });

  test("shows the dashboard loading skeleton while traffic loads", async function (assert) {
    visit("/admin/dashboard/traffic?range=last_30_days");

    const request = await pendingRequest;
    await waitFor("[data-test-site-traffic-skeleton]");

    assert.dom("[data-test-site-traffic-skeleton]").exists();
    assert.dom(".site-traffic-explorer__loading").doesNotExist();
    assert
      .dom(".route-loading-spinner")
      .doesNotExist("keeps the explorer skeleton as the loading indicator");

    pretender.resolve(request);
    await settled();

    assert.dom("[data-test-site-traffic-skeleton]").doesNotExist();
    assert.dom("[data-test-site-traffic-metric='pageviews']").exists();
  });
});

acceptance("Admin | Site Traffic Explorer | Crawler traffic", function (needs) {
  needs.user();
  needs.settings({
    dashboard_improvements: true,
    improved_crawler_detection: true,
  });
  needs.pretender((server, helper) => {
    server.get("/admin/dashboard/traffic.json", () => {
      return helper.response(crawlerOnlyResponse());
    });
  });

  test("shows traffic containing only likely crawlers", async function (assert) {
    await visit("/admin/dashboard/traffic?range=last_30_days");

    assert.dom("[data-test-site-traffic-empty]").doesNotExist();
    assert.dom("[data-test-traffic-series='likely-crawler']").hasText("1");
  });
});

acceptance("Admin | Site Traffic Explorer | Errors", function (needs) {
  let errorType = "traffic_query_timeout";

  needs.user();
  needs.settings({
    dashboard_improvements: true,
    improved_crawler_detection: true,
  });
  needs.pretender((server, helper) => {
    server.get("/admin/dashboard/traffic.json", () =>
      helper.response(503, { error_type: errorType })
    );
  });

  test("distinguishes timeout and unexpected failures", async function (assert) {
    await visit("/admin/dashboard/traffic?range=last_30_days");

    assert
      .dom("[role='alert'] p")
      .hasText(
        "This traffic query took too long. Choose a shorter date range and try again."
      );

    errorType = "unexpected";
    await click("[role='alert'] button");

    assert
      .dom("[role='alert'] p")
      .hasText("Couldn't load site traffic. Try again.");
  });
});
