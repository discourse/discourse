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

  test("changing dates refreshes nearby sections without fetching dashboard metadata", async function (assert) {
    const controller = this.owner.lookup("controller:admin/dashboard");
    const oldStartDate = new Date("2026-06-25T00:00:00Z");
    const oldEndDate = new Date("2026-07-24T23:59:59Z");
    controller.loadedSections = {
      period: "last_30_days",
      startDate: oldStartDate,
      endDate: oldEndDate,
      sections: [
        {
          id: "traffic",
          data: { pageviews: 30 },
          loaded: true,
          loading: false,
          error: false,
          stale: false,
          period: "last_30_days",
          startDate: oldStartDate,
          endDate: oldEndDate,
        },
        {
          id: "search",
          data: null,
          loaded: false,
          loading: false,
          error: false,
          stale: false,
        },
      ],
    };
    const fetch = sinon.stub(AdminDashboard, "fetch");
    const fetchSection = sinon
      .stub(AdminDashboard, "fetchSection")
      .resolves({ data: { pageviews: 7 } });

    controller.setCustomDateRange(
      new Date("2026-07-18T00:00:00Z"),
      new Date("2026-07-24T00:00:00Z")
    );

    assert.strictEqual(fetch.callCount, 0);
    assert.true(controller.loadedSections.sections[0].stale);
    assert.strictEqual(
      controller.loadedSections.sections[0].startDate,
      oldStartDate
    );

    await controller.loadSection("search", { isIntersecting: false });
    assert.strictEqual(fetchSection.callCount, 0);

    await controller.loadSection("traffic", { isIntersecting: true });
    assert.strictEqual(fetchSection.callCount, 1);
    assert.strictEqual(
      fetchSection.firstCall.args[1].startDate,
      controller.loadedSections.startDate
    );
    assert.strictEqual(
      fetchSection.firstCall.args[1].endDate,
      controller.loadedSections.endDate
    );
    assert.deepEqual(controller.loadedSections.sections[0].data, {
      pageviews: 7,
    });
  });

  test("section refreshes do not use the page loading indicator", async function (assert) {
    const controller = this.owner.lookup("controller:admin/dashboard");
    const startDate = new Date("2026-07-18T00:00:00Z");
    const endDate = new Date("2026-07-24T23:59:59Z");
    controller.loadedSections = {
      period: "last_30_days",
      startDate,
      endDate,
      sections: [
        {
          id: "highlights",
          data: { signups: 30 },
          loaded: true,
          loading: false,
          error: false,
          stale: false,
        },
        {
          id: "traffic",
          data: { pageviews: 30 },
          loaded: true,
          loading: false,
          error: false,
          stale: false,
        },
      ],
    };
    const pendingRequests = [];
    sinon.stub(AdminDashboard, "fetchSection").callsFake(
      () =>
        new Promise((resolve) => {
          pendingRequests.push(resolve);
        })
    );

    controller.setPeriod("last_7_days");
    const highlightsRequest = controller.loadSection("highlights", {
      isIntersecting: true,
    });
    const trafficRequest = controller.loadSection("traffic", {
      isIntersecting: true,
    });

    assert.strictEqual(
      pendingRequests.length,
      2,
      "only intersecting sections start requests"
    );
    assert.false(
      controller.loadingSlider.loading,
      "section requests do not start the page loading indicator"
    );

    pendingRequests[0]({ data: { signups: 7 } });
    await highlightsRequest;
    assert.false(
      controller.loadingSlider.loading,
      "the page loading indicator remains inactive while another section loads"
    );

    pendingRequests[1]({ data: { pageviews: 7 } });
    await trafficRequest;
    assert.false(
      controller.loadingSlider.loading,
      "the page loading indicator remains inactive after sections finish"
    );
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

  test("a newly enabled section waits for its configuration to persist across a date change", async function (assert) {
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
    controller.setCustomDateRange(
      new Date("2026-07-18T00:00:00Z"),
      new Date("2026-07-24T00:00:00Z")
    );
    controller.loadSection("search");

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
