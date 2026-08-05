import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { loadDashboardReports } from "discourse/admin/lib/dashboard-reports-loader";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Unit | Lib | dashboard-reports-loader", function (hooks) {
  setupTest(hooks);

  test("returns an empty map without making a request when there are no items", async function (assert) {
    pretender.post("/admin/dashboard/reports/bulk", () => {
      throw new Error("should not be called");
    });

    const result = await loadDashboardReports({ items: [], filters: {} });

    assert.strictEqual(result.size, 0);
  });

  test("maps each response entry to its payload and error state, keyed by item key", async function (assert) {
    pretender.post("/admin/dashboard/reports/bulk", () =>
      response({
        items: [
          {
            source: "core_report",
            identifier: "signups",
            key: "core_report:signups",
            data: { type: "signups" },
          },
          {
            source: "core_report",
            identifier: "broken",
            key: "core_report:broken",
            data: null,
            error: true,
          },
        ],
      })
    );

    const result = await loadDashboardReports({
      items: [
        { source: "core_report", identifier: "signups" },
        { source: "core_report", identifier: "broken" },
      ],
      filters: {},
    });

    assert.deepEqual(
      result.get("core_report:signups"),
      { payload: { type: "signups" }, error: false },
      "a successful item has its payload and error: false"
    );
    assert.deepEqual(
      result.get("core_report:broken"),
      { payload: null, error: true },
      "a failed item has a null payload and error: true"
    );
  });
});
