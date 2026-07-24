import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import AdminDashboard from "discourse/admin/models/admin-dashboard";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Unit | Controller | admin-dashboard", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    sinon.restore();
  });

  test("a section refresh supersedes an in-flight request", async function (assert) {
    const controller = this.owner.lookup("controller:admin/dashboard");
    const startDate = new Date("2026-06-25T00:00:00Z");
    const endDate = new Date("2026-07-24T23:59:59Z");
    controller.loadedSections = {
      period: "last_30_days",
      startDate,
      endDate,
      sections: [
        {
          id: "reports",
          data: { items: [{ key: "old" }] },
          loaded: true,
          loading: false,
          error: false,
          stale: true,
          period: "last_30_days",
          startDate,
          endDate,
        },
      ],
    };

    let resolveFirstRequest;
    let resolveSecondRequest;
    const firstResponse = new Promise((resolve) => {
      resolveFirstRequest = resolve;
    });
    const secondResponse = new Promise((resolve) => {
      resolveSecondRequest = resolve;
    });
    const fetchSection = sinon.stub(AdminDashboard, "fetchSection");
    fetchSection.onFirstCall().returns(firstResponse);
    fetchSection.onSecondCall().returns(secondResponse);

    const firstRequest = controller.loadSection("reports");
    const refreshRequest = controller.refreshSection("reports");
    resolveSecondRequest({ data: { items: [{ key: "new" }] } });
    await refreshRequest;
    resolveFirstRequest({ data: { items: [{ key: "obsolete" }] } });
    await firstRequest;

    assert.strictEqual(fetchSection.callCount, 2);
    assert.deepEqual(controller.loadedSections.sections[0].data, {
      items: [{ key: "new" }],
    });
  });

  test("a newly enabled section waits for its configuration to persist", async function (assert) {
    const controller = this.owner.lookup("controller:admin/dashboard");
    controller.loadedSections = {
      period: "last_30_days",
      startDate: new Date("2026-06-25T00:00:00Z"),
      endDate: new Date("2026-07-24T23:59:59Z"),
      sections: [],
      configuration: { sections: [{ id: "search", visible: false }] },
    };
    pretender.put("/admin/dashboard/configuration.json", () => response({}));
    const fetchSection = sinon
      .stub(AdminDashboard, "fetchSection")
      .resolves({ data: { searches: 10 } });

    controller.toggleSection("search");
    await controller.loadSection("search");

    assert.true(controller.loadedSections.sections[0].configurationPending);
    assert.strictEqual(fetchSection.callCount, 0);

    await settled();
    await controller.loadSection("search");

    assert.false(controller.loadedSections.sections[0].configurationPending);
    assert.strictEqual(fetchSection.callCount, 1);
    assert.deepEqual(controller.loadedSections.sections[0].data, {
      searches: 10,
    });
  });

  test("a hidden stale section retains its data and date context when restored", async function (assert) {
    const controller = this.owner.lookup("controller:admin/dashboard");
    const oldStartDate = new Date("2026-06-25T00:00:00Z");
    const oldEndDate = new Date("2026-07-24T23:59:59Z");
    controller.loadedSections = {
      period: "last_7_days",
      startDate: new Date("2026-07-18T00:00:00Z"),
      endDate: oldEndDate,
      sections: [
        {
          id: "traffic",
          data: { pageviews: 30 },
          loaded: true,
          loading: false,
          error: false,
          stale: true,
          period: "last_30_days",
          startDate: oldStartDate,
          endDate: oldEndDate,
        },
      ],
      configuration: { sections: [{ id: "traffic", visible: true }] },
    };
    pretender.put("/admin/dashboard/configuration.json", () => response({}));
    const fetchSection = sinon.stub(AdminDashboard, "fetchSection");

    controller.toggleSection("traffic");
    await settled();
    controller.toggleSection("traffic");

    const restored = controller.loadedSections.sections[0];
    assert.deepEqual(restored.data, { pageviews: 30 });
    assert.strictEqual(restored.period, "last_30_days");
    assert.strictEqual(restored.startDate, oldStartDate);
    assert.strictEqual(restored.endDate, oldEndDate);
    assert.true(restored.stale);
    assert.true(restored.configurationPending);

    await controller.loadSection("traffic");
    assert.strictEqual(fetchSection.callCount, 0);

    await settled();
    assert.false(controller.loadedSections.sections[0].configurationPending);
  });

  test("a failed hidden refresh restores an actionable stale section", async function (assert) {
    const controller = this.owner.lookup("controller:admin/dashboard");
    const startDate = new Date("2026-06-25T00:00:00Z");
    const endDate = new Date("2026-07-24T23:59:59Z");
    controller.loadedSections = {
      period: "last_7_days",
      startDate: new Date("2026-07-18T00:00:00Z"),
      endDate,
      sections: [
        {
          id: "traffic",
          data: { pageviews: 30 },
          loaded: true,
          loading: false,
          error: false,
          stale: true,
          period: "last_30_days",
          startDate,
          endDate,
        },
      ],
      configuration: { sections: [{ id: "traffic", visible: true }] },
    };
    pretender.put("/admin/dashboard/configuration.json", () => response({}));
    let rejectRequest;
    sinon.stub(AdminDashboard, "fetchSection").returns(
      new Promise((_resolve, reject) => {
        rejectRequest = reject;
      })
    );

    const request = controller.loadSection("traffic");
    controller.toggleSection("traffic");
    rejectRequest(new Error("failed"));
    await request;
    controller.toggleSection("traffic");
    await settled();

    const restored = controller.loadedSections.sections[0];
    assert.deepEqual(restored.data, { pageviews: 30 });
    assert.false(restored.loading);
    assert.true(restored.error);
    assert.true(restored.stale);
    assert.strictEqual(restored.startDate, startDate);
    assert.strictEqual(restored.endDate, endDate);
  });
});
