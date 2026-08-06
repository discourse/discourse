import {
  click,
  currentURL,
  focus,
  triggerKeyEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

function response(pageviews = 2) {
  const row = { value: "US", label: "United States", pageviews };

  return {
    partial_data: null,
    summary: {
      pageviews,
      distinct_sessions: 1,
      logged_in_share: 100,
      bounce_rate: 0,
      average_session_duration_seconds: 30,
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
    dimensions: {
      top_urls: [{ value: "/latest", label: "/latest", pageviews }],
      entry_urls: [{ value: "/latest", label: "/latest", pageviews: 1 }],
      referrers: [{ value: "", label: "Direct / unknown", pageviews: 1 }],
      countries: [row],
      networks: [
        { value: "AS64496", label: "AS64496 Example Network", pageviews },
      ],
      browsers: [{ value: "chrome", label: "Chrome", pageviews }],
      ip_addresses: [{ value: "192.0.2.1", label: "192.0.2.1", pageviews }],
    },
  };
}

acceptance("Admin | Site Traffic Explorer", function (needs) {
  needs.user();
  needs.settings({
    dashboard_improvements: true,
    improved_crawler_detection: true,
  });
  needs.pretender((server, helper) => {
    server.get("/admin/dashboard/traffic.json", (request) => {
      return helper.response(response(request.queryParams.country ? 1 : 2));
    });
  });

  test("shows the response and applies a row filter", async function (assert) {
    await visit(
      "/admin/dashboard/traffic?end_date=2026-05-12&range=custom&start_date=2026-05-01"
    );

    assert.dom("h1").hasText("Site Traffic Explorer");
    assert.dom("[data-test-site-traffic-metric='pageviews']").includesText("2");
    assert
      .dom("[data-test-site-traffic-card='visitors'] .d-icon-fab-chrome")
      .exists("shows a browser icon");

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
      .includesText("🇺🇸", "shows a country flag");
    await click("button[aria-label='Filter by United States']");

    assert
      .dom("[data-test-site-traffic-filter-pill='country']")
      .hasText("Country is United States");
    assert.dom("[data-test-site-traffic-metric='pageviews']").includesText("1");
    assert.strictEqual(
      currentURL(),
      "/admin/dashboard/traffic?country=US&end_date=2026-05-12&range=custom&start_date=2026-05-01"
    );
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
