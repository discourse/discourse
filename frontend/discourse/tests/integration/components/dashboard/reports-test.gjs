import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardReports from "discourse/admin/components/dashboard/reports";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | DashboardReports", function (hooks) {
  setupRenderingTest(hooks);

  test("renders card payloads from the section data without another request", async function (assert) {
    let bulkRequestCount = 0;
    pretender.post("/admin/dashboard/reports/bulk", () => {
      bulkRequestCount += 1;
      return response({ items: [] });
    });
    const data = {
      items: [
        {
          source: "core_report",
          identifier: "activity",
          key: "core_report:activity",
          title: "Activity",
          url: "/admin/reports/activity",
          payload: { empty: true },
        },
      ],
    };

    await render(<template><DashboardReports @data={{data}} /></template>);

    assert.dom(".db-report__name").hasText("Activity");
    assert.dom(".db-report__empty").exists();
    assert.strictEqual(bulkRequestCount, 0);
  });
});
