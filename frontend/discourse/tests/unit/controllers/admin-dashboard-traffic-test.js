import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  ALL_PRESETS,
  calculatePresetStartDate,
  PERIOD_CUSTOM,
} from "discourse/admin/lib/dashboard-date-range";

module("Unit | Controller | admin-dashboard-traffic", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.originalUrl = `${window.location.pathname}${window.location.search}${window.location.hash}`;
    this.clock = sinon.useFakeTimers({
      now: new Date("2026-08-05T12:00:00Z"),
      shouldAdvanceTime: false,
    });
    this.controller = this.owner.lookup("controller:admin-dashboard-traffic");
  });

  hooks.afterEach(function () {
    this.clock.restore();
    window.history.replaceState(window.history.state, "", this.originalUrl);
  });

  test("period identifies each preset date range", function (assert) {
    for (const period of ALL_PRESETS) {
      this.controller.start_date = moment(
        calculatePresetStartDate(period)
      ).format("YYYY-MM-DD");
      this.controller.end_date = moment().format("YYYY-MM-DD");

      assert.strictEqual(
        this.controller.period,
        period,
        `identifies ${period}`
      );
    }
  });

  test("period identifies a custom date range", function (assert) {
    this.controller.start_date = "2026-07-01";
    this.controller.end_date = "2026-07-14";

    assert.strictEqual(this.controller.period, PERIOD_CUSTOM);
  });

  test("safe filters use individual query parameters", function (assert) {
    assert.deepEqual(this.controller.queryParams, [
      "start_date",
      "end_date",
      "country",
      "asn",
      "browser",
    ]);

    this.controller.setSafeFilters({
      country: "US",
      asn: "AS15169",
      browser: "firefox",
    });

    assert.strictEqual(this.controller.country, "US");
    assert.strictEqual(this.controller.asn, "AS15169");
    assert.strictEqual(this.controller.browser, "firefox");
    assert.false(this.controller.queryParams.includes("url"));
    assert.false(this.controller.queryParams.includes("ip"));
  });

  test("migrates valid legacy safe fragments before the detail component mounts", function (assert) {
    const fetchStub = sinon.stub(window, "fetch");
    window.history.replaceState(
      window.history.state,
      "",
      "/admin/dashboard/traffic?start_date=2026-07-01&end_date=2026-07-31#country=US&asn=AS15169&browser=firefox&url=%2Fsecret&ip=192.0.2.1"
    );

    const route = this.owner.lookup("route:admin-dashboard-traffic");
    route.setupController(this.controller, null, {
      to: {
        queryParams: {
          start_date: "2026-07-01",
          end_date: "2026-07-31",
        },
      },
    });

    assert.strictEqual(this.controller.country, "US");
    assert.strictEqual(this.controller.asn, "AS15169");
    assert.strictEqual(this.controller.browser, "firefox");
    assert.strictEqual(window.location.hash, "", "the legacy fragment clears");

    const queryParams = new URLSearchParams(window.location.search);
    assert.strictEqual(queryParams.get("country"), "US");
    assert.strictEqual(queryParams.get("asn"), "AS15169");
    assert.strictEqual(queryParams.get("browser"), "firefox");
    assert.false(queryParams.has("url"), "the URL filter is not migrated");
    assert.false(queryParams.has("ip"), "the IP filter is not migrated");
    assert.false(
      fetchStub.called,
      "the route migration does not start an analytics request"
    );
    fetchStub.restore();
  });
});
