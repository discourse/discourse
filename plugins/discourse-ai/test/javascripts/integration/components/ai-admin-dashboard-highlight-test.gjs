import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender from "discourse/tests/helpers/create-pretender";
import AiAdminDashboardHighlight from "discourse/plugins/discourse-ai/discourse/connectors/admin-dashboard-highlights-before-kpis/ai-admin-dashboard-highlight";

const OUTLET_ARGS = {
  period: "last_30_days",
  startDate: "2026-05-01",
  endDate: "2026-06-01",
  kpis: [],
};

module("Integration | Component | AiAdminDashboardHighlight", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the highlight returned by the endpoint", async function (assert) {
    pretender.get(
      "/admin/plugins/discourse-ai/admin-dashboard-highlights.json",
      () => [
        200,
        { "Content-Type": "application/json" },
        { highlight: "Your community grew to 1,100 new members." },
      ]
    );

    await render(
      <template>
        <AiAdminDashboardHighlight @outletArgs={{OUTLET_ARGS}} />
      </template>
    );

    assert
      .dom(".ai-admin-dashboard-highlight__text")
      .hasText(
        "Your community grew to 1,100 new members.",
        "it renders the returned highlight"
      );
    assert
      .dom(".ai-admin-dashboard-highlight")
      .hasAttribute("aria-live", "polite", "it announces the loaded highlight");
  });

  test("requests highlights for the same local dates as the dashboard sections", async function (assert) {
    const outletArgs = {
      period: "custom",
      startDate: moment.parseZone("2026-05-01T00:00:00-04:00"),
      endDate: moment.parseZone("2026-05-31T23:59:59-04:00"),
      kpis: [],
    };

    pretender.get(
      "/admin/plugins/discourse-ai/admin-dashboard-highlights.json",
      (request) => {
        assert.strictEqual(
          request.queryParams.start_date,
          "2026-05-01",
          "it preserves the selected start date"
        );
        assert.strictEqual(
          request.queryParams.end_date,
          "2026-05-31",
          "it preserves the selected end date"
        );

        return [
          200,
          { "Content-Type": "application/json" },
          { highlight: "May stayed aligned with the KPI tiles." },
        ];
      }
    );

    await render(
      <template>
        <AiAdminDashboardHighlight @outletArgs={{outletArgs}} />
      </template>
    );

    assert
      .dom(".ai-admin-dashboard-highlight__text")
      .hasText(
        "May stayed aligned with the KPI tiles.",
        "it renders the returned highlight"
      );
  });

  test("renders nothing when the endpoint fails", async function (assert) {
    pretender.get(
      "/admin/plugins/discourse-ai/admin-dashboard-highlights.json",
      () => [500, { "Content-Type": "application/json" }, {}]
    );

    await render(
      <template>
        <AiAdminDashboardHighlight @outletArgs={{OUTLET_ARGS}} />
      </template>
    );

    assert
      .dom(".ai-admin-dashboard-highlight")
      .doesNotExist("it hides the highlight region after a failed request");
  });

  test("shouldRender follows the admin dashboard AI setting", function (assert) {
    assert.true(
      AiAdminDashboardHighlight.shouldRender(
        {},
        { siteSettings: { ai_admin_dashboard_enabled: true } }
      )
    );
    assert.false(
      AiAdminDashboardHighlight.shouldRender(
        {},
        { siteSettings: { ai_admin_dashboard_enabled: false } }
      )
    );
  });
});
