import { array } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import RedesignedAdminDashboard from "discourse/admin/components/redesigned-admin-dashboard";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | RedesignedAdminDashboard", function (hooks) {
  setupRenderingTest(hooks);

  test("keeps loaded section content visible while refreshing", async function (assert) {
    const startDate = new Date("2026-07-18T00:00:00Z");
    const endDate = new Date("2026-07-24T23:59:59Z");
    const loadedSections = {
      period: "last_7_days",
      startDate,
      endDate,
      sections: [
        {
          id: "reports",
          data: { items: [] },
          loaded: true,
          loading: true,
          error: false,
          stale: true,
          period: "last_30_days",
          startDate,
          endDate,
        },
      ],
      configuration: {
        sections: [{ id: "reports", visible: true }],
      },
    };
    const noop = () => {};

    await render(
      <template>
        <RedesignedAdminDashboard
          @requestedPeriod="last_7_days"
          @requestedStartDate={{startDate}}
          @requestedEndDate={{endDate}}
          @setPeriod={{noop}}
          @setCustomDateRange={{noop}}
          @loadedSections={{loadedSections}}
          @toggleSection={{noop}}
          @reorderSections={{noop}}
          @refreshSection={{noop}}
          @loadSection={{noop}}
          @retrySection={{noop}}
          @loadingSections={{false}}
          @sectionsFetchError={{false}}
          @problems={{array}}
          @onRefreshProblems={{noop}}
          @onIgnoreProblem={{noop}}
        />
      </template>
    );

    assert
      .dom('[data-section-id="reports"]')
      .hasAttribute("aria-busy", "true", "the section is marked as busy");
    assert
      .dom(".db-section-container__loading")
      .hasText("Loading Reports…", "the section shows refresh feedback");
    assert
      .dom(".db-section__header")
      .hasText("Reports", "the loaded section content remains visible");
  });
});
