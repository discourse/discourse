import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Unit | Controller | admin-site-traffic", function (hooks) {
  setupTest(hooks);

  test("reconciles accepted filters with canonical response values", async function (assert) {
    const controller = this.owner.lookup("controller:admin-site-traffic");
    controller.top_url = "https://forum.example/latest/?sort=recent";
    pretender.get("/admin/dashboard/site-traffic-explorer.json", () =>
      response({
        dimensions: {
          top_urls: [{ value: "/latest", label: "/latest", pageviews: 1 }],
        },
        active_filters: [
          { key: "top_url", value: "/latest", label: "/latest" },
        ],
      })
    );

    await controller.fetchTraffic();

    assert.strictEqual(
      controller.top_url,
      "/latest",
      "the query parameter uses the canonical value"
    );
    assert.deepEqual(
      controller.activeFilters,
      [
        {
          key: "top_url",
          pending: false,
          values: [{ value: "/latest", label: "/latest" }],
        },
      ],
      "the pill and checkbox state use the canonical value"
    );
    assert.true(
      controller.isFilterSelected("top_url", "/latest"),
      "the canonical result row is selected"
    );
  });
});
