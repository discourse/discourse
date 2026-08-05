import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardTraffic from "discourse/admin/components/dashboard/traffic";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const TRAFFIC = {
  kpis: {
    browser_pageviews: { value: 5, percent_change: null },
  },
  pageview_series: [],
};

module("Integration | Component | Dashboard | Traffic", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.traffic = TRAFFIC;
    this.startDate = new Date("2026-05-01T00:00:00Z");
    this.endDate = new Date("2026-05-12T23:59:59Z");
  });

  test("shows the detail action to admins", async function (assert) {
    this.currentUser.set("admin", true);

    await render(
      <template>
        <DashboardTraffic
          @traffic={{this.traffic}}
          @period="custom"
          @startDate={{this.startDate}}
          @endDate={{this.endDate}}
        />
      </template>
    );

    assert
      .dom(".db-traffic__see-details")
      .hasText("See details")
      .hasAttribute(
        "href",
        "/admin/dashboard/traffic?end_date=2026-05-12&start_date=2026-05-01"
      );
  });

  test("hides the detail action from non-admin staff", async function (assert) {
    this.currentUser.setProperties({ admin: false, moderator: true });

    await render(
      <template>
        <DashboardTraffic
          @traffic={{this.traffic}}
          @period="custom"
          @startDate={{this.startDate}}
          @endDate={{this.endDate}}
        />
      </template>
    );

    assert.dom(".db-traffic__see-details").doesNotExist();
  });
});
