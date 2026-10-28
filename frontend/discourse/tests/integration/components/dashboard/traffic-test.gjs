import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardTraffic from "discourse/admin/components/dashboard/traffic";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const startDate = new Date("2026-05-01");
const endDate = new Date("2026-05-14");
const entryUrlCard = ".db-section__row-block:nth-child(2)";

function trafficWithEntryUrls(topEntryUrls) {
  return {
    kpis: { browser_pageviews: { value: 0 } },
    pageview_series: [],
    top_entry_urls: topEntryUrls,
  };
}

module("Integration | Component | Dashboard | Traffic", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  test("renders the entry URL loading placeholder for admins", async function (assert) {
    this.currentUser.admin = true;

    await render(
      <template>
        <DashboardTraffic
          @endDate={{endDate}}
          @startDate={{startDate}}
          @traffic={{null}}
        />
      </template>
    );

    assert
      .dom(".db-traffic__list-shell")
      .exists({ count: 3 }, "shows all three loading placeholders");
    assert
      .dom(`${entryUrlCard} .db-section__row-block-title`)
      .hasText("Top entry URLs", "places it beside Top referrers");
  });

  test("renders the entry URL report error", async function (assert) {
    const traffic = trafficWithEntryUrls({
      rows: [],
      error: "exception",
    });

    await render(
      <template>
        <DashboardTraffic
          @endDate={{endDate}}
          @startDate={{startDate}}
          @traffic={{traffic}}
        />
      </template>
    );

    assert
      .dom(`${entryUrlCard} .db-traffic__list-error`)
      .hasText(
        "Couldn't load top entry URLs. Try refreshing the page.",
        "shows a retryable error in the entry URL card"
      );
  });

  test("renders the entry URL empty state", async function (assert) {
    const traffic = trafficWithEntryUrls({
      rows: [],
      error: null,
    });

    await render(
      <template>
        <DashboardTraffic
          @endDate={{endDate}}
          @startDate={{startDate}}
          @traffic={{traffic}}
        />
      </template>
    );

    assert
      .dom(`${entryUrlCard} .db-traffic__list-empty`)
      .hasText(
        "No entry URL data for this period.",
        "shows when no eligible entries exist"
      );
    assert
      .dom("[data-identifier='site-traffic-top-entry-urls-tooltip']")
      .doesNotExist("omits the entry URL tooltip");
  });
});
