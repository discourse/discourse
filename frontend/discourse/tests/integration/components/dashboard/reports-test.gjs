import { tracked } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import {
  find,
  render,
  settled,
  triggerEvent,
  waitFor,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardReports from "discourse/admin/components/dashboard/reports";
import { registerAdminDashboardReportRenderer } from "discourse/admin/lib/admin-dashboard-report-renderers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  logIn,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import {
  settleGestureFrame,
  stubPointerCapture,
} from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
import { i18n } from "discourse-i18n";

const FakeReportRenderer = <template>
  <div class="fake-report-renderer">{{@payload.type}}</div>
</template>;

const ITEMS = [
  {
    source: "test_source",
    identifier: "signups",
    key: "test_source:signups",
    title: "Signups",
    description: "New account signups",
    label: null,
    url: "/admin/reports/signups",
  },
  {
    source: "core_report",
    identifier: "broken",
    key: "core_report:broken",
    title: "Broken report",
    description: "Always fails to load",
    label: null,
    url: "/admin/reports/broken",
  },
  {
    source: "core_report",
    identifier: "empty_report",
    key: "core_report:empty_report",
    title: "Empty report",
    description: "Never has data",
    label: null,
    url: "/admin/reports/empty_report",
  },
];

function deferredBulkFetch() {
  let resolve;
  const promise = new Promise((r) => (resolve = r));
  pretender.post("/admin/dashboard/reports/bulk", () => promise);
  return { resolve: (body) => resolve(response(body)) };
}

function measureRowUnit(cardSelector) {
  const cardHeight = find(cardSelector).getBoundingClientRect().height;
  const rowGap =
    parseFloat(getComputedStyle(find(".db-section__wrapper")).rowGap) || 0;
  return cardHeight + rowGap;
}

function measureColUnit(cardSelector) {
  const cardWidth = find(cardSelector).getBoundingClientRect().width;
  const columnGap =
    parseFloat(getComputedStyle(find(".db-section__wrapper")).columnGap) || 0;
  return cardWidth + columnGap;
}

module("Integration | Component | DashboardReports", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    logIn(getOwner(this));
    updateCurrentUser({ admin: true });
  });

  test("displays an error when the section failed to load", async function (assert) {
    await render(
      <template>
        <DashboardReports @data={{null}} @fetchError={{true}} />
      </template>
    );

    assert
      .dom(".db-section__error")
      .hasText(
        i18n("admin.dashboard.sections.reports.fetch_error"),
        "the fetch error is shown"
      );
    assert.dom(".db-reports").doesNotExist("the reports grid is not rendered");
    assert
      .dom(".db-report__add-report")
      .doesNotExist("the add report button is not rendered");
  });

  test("shows a per-card loading spinner, then each card's own success, empty, or error state once the bulk fetch resolves", async function (assert) {
    registerAdminDashboardReportRenderer("test_source", FakeReportRenderer);

    const { resolve } = deferredBulkFetch();

    const renderPromise = render(
      <template><DashboardReports @data={{hash items=ITEMS}} /></template>
    );

    await waitFor(".db-report__card .loading-container.visible");
    assert
      .dom(".db-report__card .loading-container.visible")
      .exists(
        { count: 3 },
        "every card shows a loading spinner before the fetch resolves"
      );

    resolve({
      items: [
        {
          source: "test_source",
          identifier: "signups",
          key: "test_source:signups",
          data: { type: "signups", empty: false },
        },
        {
          source: "core_report",
          identifier: "broken",
          key: "core_report:broken",
          data: null,
          error: true,
        },
        {
          source: "core_report",
          identifier: "empty_report",
          key: "core_report:empty_report",
          data: { type: "empty_report", data: [], empty: true },
        },
      ],
    });
    await renderPromise;
    await settled();

    assert
      .dom(".db-report__card .loading-container.visible")
      .doesNotExist(
        "no card is left in a loading state once the fetch resolves"
      );

    assert
      .dom('[data-identifier="core_report:broken"] .db-report__error')
      .hasText(
        i18n("admin.dashboard.reports_section.report_error"),
        "the failed report shows its own error state"
      );
    assert
      .dom('[data-identifier="test_source:signups"] .db-report__error')
      .doesNotExist(
        "a report that loaded successfully does not show an error state"
      );

    assert
      .dom('[data-identifier="core_report:empty_report"] .db-report__empty')
      .exists("a report with no data shows the empty state");
    assert
      .dom('[data-identifier="test_source:signups"] .db-report__empty')
      .doesNotExist("a report with data does not show the empty state");
    assert
      .dom('[data-identifier="test_source:signups"] .fake-report-renderer')
      .hasText("signups", "a successful report renders its content");
  });

  test("shows a loading spinner immediately when the date range changes, instead of the stale chart", async function (assert) {
    registerAdminDashboardReportRenderer("test_source", FakeReportRenderer);

    let resolveSecondFetch;
    let fetchCount = 0;
    pretender.post("/admin/dashboard/reports/bulk", () => {
      fetchCount++;
      if (fetchCount === 1) {
        return response({
          items: [
            {
              source: "test_source",
              identifier: "signups",
              key: "test_source:signups",
              data: { type: "signups", empty: false },
            },
          ],
        });
      }
      return new Promise((resolve) => (resolveSecondFetch = resolve));
    });

    class State {
      @tracked startDate = "2026-01-01";
    }
    const state = new State();
    const singleItem = [ITEMS[0]];

    await render(
      <template>
        <DashboardReports
          @data={{hash items=singleItem}}
          @startDate={{state.startDate}}
        />
      </template>
    );

    assert
      .dom('[data-identifier="test_source:signups"] .fake-report-renderer')
      .exists("the initial load renders real content");

    state.startDate = "2026-02-01";
    await waitFor(
      '[data-identifier="test_source:signups"] .loading-container.visible'
    );
    assert
      .dom('[data-identifier="test_source:signups"] .loading-container.visible')
      .exists("changing the date range shows a loading spinner immediately");
    assert
      .dom('[data-identifier="test_source:signups"] .fake-report-renderer')
      .doesNotExist(
        "the stale chart is replaced by the spinner rather than left showing"
      );

    resolveSecondFetch(
      response({
        items: [
          {
            source: "test_source",
            identifier: "signups",
            key: "test_source:signups",
            data: { type: "signups", empty: false },
          },
        ],
      })
    );
    await settled();

    assert
      .dom('[data-identifier="test_source:signups"] .fake-report-renderer')
      .exists("the chart renders again once the new range's data resolves");
  });

  test("does not render resize handles for a non-admin viewer", async function (assert) {
    registerAdminDashboardReportRenderer("test_source", FakeReportRenderer);

    pretender.post("/admin/dashboard/reports/bulk", () =>
      response({
        items: [
          {
            source: "test_source",
            identifier: "signups",
            key: "test_source:signups",
            data: { type: "signups", empty: false },
          },
        ],
      })
    );

    updateCurrentUser({ admin: false });

    const item = { ...ITEMS[0], rows: 1, cols: 1 };

    await render(
      <template>
        <DashboardReports @data={{hash items=(array item)}} />
      </template>
    );

    assert
      .dom('[data-identifier="test_source:signups"] .db-report__resize-handle')
      .doesNotExist("a non-admin viewer cannot resize report cards");
  });

  test("toggles a card's width via a plain click on its resize handle and persists it through the layout endpoint", async function (assert) {
    registerAdminDashboardReportRenderer("test_source", FakeReportRenderer);

    pretender.post("/admin/dashboard/reports/bulk", () =>
      response({
        items: [
          {
            source: "test_source",
            identifier: "signups",
            key: "test_source:signups",
            data: { type: "signups", empty: false },
          },
        ],
      })
    );

    let putBody;
    pretender.put("/admin/dashboard/reports/layout", (request) => {
      putBody = JSON.parse(request.requestBody);
      return response(204, {});
    });

    const item = { ...ITEMS[0], rows: 1, cols: 1 };

    await render(
      <template>
        <DashboardReports @data={{hash items=(array item)}} />
      </template>
    );

    assert
      .dom('[data-identifier="test_source:signups"]')
      .doesNotHaveClass("--wide", "starts at its persisted single-column size");

    const handle = stubPointerCapture(
      '[data-identifier="test_source:signups"] .db-report__resize-handle'
    ).element;
    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });
    await triggerEvent(handle, "pointerup", {
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    assert.deepEqual(
      putBody.items,
      [{ source: "test_source", identifier: "signups", rows: 1, cols: 2 }],
      "clicking the resize handle without dragging toggles it to the smallest expanded size, wide but still a single row"
    );
  });

  test("applies a resize locally without re-fetching the dashboard or any report's chart data", async function (assert) {
    registerAdminDashboardReportRenderer("test_source", FakeReportRenderer);

    let bulkFetchCount = 0;
    pretender.post("/admin/dashboard/reports/bulk", () => {
      bulkFetchCount++;
      return response({
        items: [
          {
            source: "test_source",
            identifier: "signups",
            key: "test_source:signups",
            data: { type: "signups", empty: false },
          },
        ],
      });
    });
    pretender.put("/admin/dashboard/reports/layout", () => response(204, {}));

    let refreshSectionsCalls = 0;
    const refreshSections = () => {
      refreshSectionsCalls++;
    };

    const item = { ...ITEMS[0], rows: 1, cols: 1 };

    await render(
      <template>
        <DashboardReports
          @data={{hash items=(array item)}}
          @refreshSections={{refreshSections}}
        />
      </template>
    );

    assert.strictEqual(
      bulkFetchCount,
      1,
      "control: the initial render fetches chart data once"
    );

    const handle = stubPointerCapture(
      '[data-identifier="test_source:signups"] .db-report__resize-handle'
    ).element;
    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });
    await triggerEvent(handle, "pointerup", {
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    assert
      .dom('[data-identifier="test_source:signups"]')
      .hasClass(
        "--wide",
        "the card reflects its new persisted size immediately, from local state"
      );
    assert.strictEqual(
      refreshSectionsCalls,
      0,
      "resizing does not trigger a full dashboard refresh"
    );
    assert.strictEqual(
      bulkFetchCount,
      1,
      "resizing does not re-fetch any report's chart data"
    );
  });

  test("persists an earlier resize when a different card is resized afterward", async function (assert) {
    registerAdminDashboardReportRenderer("test_source", FakeReportRenderer);

    pretender.post("/admin/dashboard/reports/bulk", () =>
      response({
        items: [
          {
            source: "test_source",
            identifier: "signups",
            key: "test_source:signups",
            data: { type: "signups", empty: false },
          },
          {
            source: "core_report",
            identifier: "empty_report",
            key: "core_report:empty_report",
            data: { type: "empty_report", data: [], empty: true },
          },
        ],
      })
    );

    const putBodies = [];
    pretender.put("/admin/dashboard/reports/layout", (request) => {
      putBodies.push(JSON.parse(request.requestBody));
      return response(204, {});
    });

    const items = [
      { ...ITEMS[0], rows: 1, cols: 1 },
      { ...ITEMS[2], rows: 1, cols: 1 },
    ];

    await render(
      <template><DashboardReports @data={{hash items=items}} /></template>
    );

    const firstHandle = stubPointerCapture(
      '[data-identifier="test_source:signups"] .db-report__resize-handle'
    ).element;
    await triggerEvent(firstHandle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });
    await triggerEvent(firstHandle, "pointerup", {
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    const secondHandle = stubPointerCapture(
      '[data-identifier="core_report:empty_report"] .db-report__resize-handle'
    ).element;
    await triggerEvent(secondHandle, "pointerdown", {
      button: 0,
      pointerId: 2,
      clientX: 0,
      clientY: 0,
    });
    await triggerEvent(secondHandle, "pointerup", {
      pointerId: 2,
      clientX: 0,
      clientY: 0,
    });

    assert.deepEqual(
      putBodies[1].items,
      [
        { source: "test_source", identifier: "signups", rows: 1, cols: 2 },
        {
          source: "core_report",
          identifier: "empty_report",
          rows: 1,
          cols: 2,
        },
      ],
      "the second card's resize request still carries the first card's new size"
    );
  });

  test("grows the card live row by row as a drag crosses each row boundary, reflowing its sibling, then persists on release", async function (assert) {
    registerAdminDashboardReportRenderer("test_source", FakeReportRenderer);

    pretender.post("/admin/dashboard/reports/bulk", () =>
      response({
        items: [
          {
            source: "test_source",
            identifier: "signups",
            key: "test_source:signups",
            data: { type: "signups", empty: false },
          },
          {
            source: "core_report",
            identifier: "empty_report",
            key: "core_report:empty_report",
            data: { type: "empty_report", data: [], empty: true },
          },
        ],
      })
    );

    let putBody;
    pretender.put("/admin/dashboard/reports/layout", (request) => {
      putBody = JSON.parse(request.requestBody);
      return response(204, {});
    });

    const items = [
      { ...ITEMS[0], rows: 1, cols: 1 },
      { ...ITEMS[2], rows: 1, cols: 1 },
    ];

    await render(
      <template><DashboardReports @data={{hash items=items}} /></template>
    );

    assert
      .dom('[data-identifier="test_source:signups"]')
      .doesNotHaveClass("--rows-2", "starts at its persisted single-row size");
    assert
      .dom('[data-identifier="core_report:empty_report"]')
      .hasAttribute(
        "data-column",
        "1",
        "control: the second card starts in the right column"
      );

    const handle = stubPointerCapture(
      '[data-identifier="test_source:signups"] .db-report__resize-handle'
    ).element;
    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    const unit = measureRowUnit('[data-identifier="test_source:signups"]');
    await triggerEvent(handle, "pointermove", {
      pointerId: 1,
      clientX: 0,
      clientY: Math.ceil(unit * 0.6),
    });
    await settleGestureFrame();
    await settleGestureFrame();

    assert
      .dom('[data-identifier="test_source:signups"]')
      .hasClass(
        "--rows-2",
        "the dragged card grows live, before release, like a textarea"
      );
    assert
      .dom('[data-identifier="test_source:signups"]')
      .hasClass(
        "--wide",
        "growing past one row forces it to span the full width too"
      );
    assert
      .dom('[data-identifier="core_report:empty_report"]')
      .hasAttribute(
        "data-column",
        "0",
        "its sibling is pushed to a fresh row by the real grid reflow, not left in place under an overlay"
      );

    await triggerEvent(handle, "pointermove", {
      pointerId: 1,
      clientX: 0,
      clientY: Math.ceil(unit * 0.3),
    });

    assert
      .dom('[data-identifier="test_source:signups"]')
      .doesNotHaveClass(
        "--rows-2",
        "dragging back under the boundary shrinks it live again"
      );
    assert
      .dom('[data-identifier="core_report:empty_report"]')
      .hasAttribute(
        "data-column",
        "1",
        "and its sibling's column reflows back too"
      );

    await triggerEvent(handle, "pointermove", {
      pointerId: 1,
      clientX: 0,
      clientY: Math.ceil(unit * 1.6),
    });

    assert
      .dom('[data-identifier="test_source:signups"]')
      .hasClass("--rows-3", "crossing the next boundary grows it another row");

    await triggerEvent(handle, "pointerup", {
      pointerId: 1,
      clientX: 0,
      clientY: Math.ceil(unit * 1.6),
    });

    assert.deepEqual(
      putBody.items,
      [
        { source: "test_source", identifier: "signups", rows: 3, cols: 2 },
        {
          source: "core_report",
          identifier: "empty_report",
          rows: 1,
          cols: 1,
        },
      ],
      "releasing persists the row count it landed on, forcing the full width along with it"
    );
    assert
      .dom('[data-identifier="test_source:signups"]')
      .doesNotHaveClass(
        "--floating",
        "it settles back into the grid instead of staying fixed-positioned"
      );
    assert
      .dom(".db-report__card.--resize-placeholder")
      .doesNotExist("the placeholder is gone once the drag ends");
  });

  test("commits a card to spanning both columns while staying a single row when dragged mostly horizontally", async function (assert) {
    registerAdminDashboardReportRenderer("test_source", FakeReportRenderer);

    pretender.post("/admin/dashboard/reports/bulk", () =>
      response({
        items: [
          {
            source: "test_source",
            identifier: "signups",
            key: "test_source:signups",
            data: { type: "signups", empty: false },
          },
          {
            source: "core_report",
            identifier: "empty_report",
            key: "core_report:empty_report",
            data: { type: "empty_report", data: [], empty: true },
          },
        ],
      })
    );

    let putBody;
    pretender.put("/admin/dashboard/reports/layout", (request) => {
      putBody = JSON.parse(request.requestBody);
      return response(204, {});
    });

    const items = [
      { ...ITEMS[0], rows: 1, cols: 1 },
      { ...ITEMS[2], rows: 1, cols: 1 },
    ];

    await render(
      <template><DashboardReports @data={{hash items=items}} /></template>
    );

    assert
      .dom('[data-identifier="test_source:signups"]')
      .doesNotHaveClass("--wide", "starts at its persisted single-column size");

    const handle = stubPointerCapture(
      '[data-identifier="test_source:signups"] .db-report__resize-handle'
    ).element;
    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });

    const unit = measureColUnit('[data-identifier="test_source:signups"]');
    await triggerEvent(handle, "pointermove", {
      pointerId: 1,
      clientX: Math.ceil(unit * 0.6),
      clientY: 1,
    });
    await settleGestureFrame();
    await settleGestureFrame();

    assert
      .dom('[data-identifier="test_source:signups"]')
      .hasClass(
        "--wide",
        "a mostly-horizontal drag commits the card to spanning both columns"
      );
    assert
      .dom('[data-identifier="test_source:signups"]')
      .doesNotHaveClass(
        "--rows-2",
        "it stays a single row since the drag barely moved vertically"
      );
    assert
      .dom('[data-identifier="core_report:empty_report"]')
      .hasAttribute(
        "data-column",
        "0",
        "its sibling is pushed to a fresh row now that the wide card fills the whole row"
      );

    await triggerEvent(handle, "pointermove", {
      pointerId: 1,
      clientX: Math.ceil(unit * 0.3),
      clientY: 1,
    });

    assert
      .dom('[data-identifier="test_source:signups"]')
      .doesNotHaveClass(
        "--wide",
        "dragging back under the boundary shrinks it to a single column again"
      );

    await triggerEvent(handle, "pointermove", {
      pointerId: 1,
      clientX: Math.ceil(unit * 0.6),
      clientY: 1,
    });
    await triggerEvent(handle, "pointerup", {
      pointerId: 1,
      clientX: Math.ceil(unit * 0.6),
      clientY: 1,
    });

    assert.deepEqual(
      putBody.items,
      [
        { source: "test_source", identifier: "signups", rows: 1, cols: 2 },
        {
          source: "core_report",
          identifier: "empty_report",
          rows: 1,
          cols: 1,
        },
      ],
      "releasing persists the wide-but-single-row size"
    );
  });

  test("renders both bottom corners on a wide card, and each shrinks it while keeping the opposite edge fixed", async function (assert) {
    registerAdminDashboardReportRenderer("test_source", FakeReportRenderer);

    pretender.post("/admin/dashboard/reports/bulk", () =>
      response({
        items: [
          {
            source: "test_source",
            identifier: "signups",
            key: "test_source:signups",
            data: { type: "signups", empty: false },
          },
        ],
      })
    );

    let putBody;
    pretender.put("/admin/dashboard/reports/layout", (request) => {
      putBody = JSON.parse(request.requestBody);
      return response(204, {});
    });

    const item = { ...ITEMS[0], rows: 1, cols: 2 };

    await render(
      <template>
        <DashboardReports @data={{hash items=(array item)}} />
      </template>
    );

    assert
      .dom(
        '[data-identifier="test_source:signups"] .db-report__resize-handle.--se'
      )
      .exists("a wide card renders a bottom-right handle");
    assert
      .dom(
        '[data-identifier="test_source:signups"] .db-report__resize-handle.--sw'
      )
      .exists("and also a bottom-left handle");

    const card = find('[data-identifier="test_source:signups"]');
    const originalRect = card.getBoundingClientRect();
    const columnGap =
      parseFloat(getComputedStyle(find(".db-section__wrapper")).columnGap) || 0;
    const singleWidth = (originalRect.width - columnGap) / 2;
    const colUnit = originalRect.width - singleWidth;

    const seHandle = stubPointerCapture(
      '[data-identifier="test_source:signups"] .db-report__resize-handle.--se'
    ).element;
    await triggerEvent(seHandle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });
    await triggerEvent(seHandle, "pointermove", {
      pointerId: 1,
      clientX: -Math.ceil(colUnit * 0.6),
      clientY: 1,
    });
    await settleGestureFrame();
    await settleGestureFrame();

    assert
      .dom('[data-identifier="test_source:signups"]')
      .doesNotHaveClass(
        "--wide",
        "dragging the bottom-right handle toward the card's center shrinks it"
      );

    await triggerEvent(seHandle, "pointerup", {
      pointerId: 1,
      clientX: -Math.ceil(colUnit * 0.6),
      clientY: 1,
    });

    assert.deepEqual(
      putBody.items,
      [{ source: "test_source", identifier: "signups", rows: 1, cols: 1 }],
      "releasing persists the shrunk single-column size"
    );

    await triggerEvent(seHandle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });
    await triggerEvent(seHandle, "pointerup", {
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });
    assert
      .dom('[data-identifier="test_source:signups"]')
      .hasClass("--wide", "control: back to wide for the next drag");

    const swHandle = stubPointerCapture(
      '[data-identifier="test_source:signups"] .db-report__resize-handle.--sw'
    ).element;
    await triggerEvent(swHandle, "pointerdown", {
      button: 0,
      pointerId: 2,
      clientX: 0,
      clientY: 0,
    });
    await triggerEvent(swHandle, "pointermove", {
      pointerId: 2,
      clientX: Math.ceil(colUnit * 0.6),
      clientY: 1,
    });
    await settleGestureFrame();
    await settleGestureFrame();

    assert
      .dom('[data-identifier="test_source:signups"]')
      .doesNotHaveClass(
        "--wide",
        "dragging the bottom-left handle toward the card's center shrinks it too"
      );

    await triggerEvent(swHandle, "pointerup", {
      pointerId: 2,
      clientX: Math.ceil(colUnit * 0.6),
      clientY: 1,
    });

    assert.deepEqual(
      putBody.items,
      [{ source: "test_source", identifier: "signups", rows: 1, cols: 1 }],
      "releasing again persists the shrunk single-column size"
    );
  });

  test("clamps the live row count at the maximum during an extreme drag", async function (assert) {
    registerAdminDashboardReportRenderer("test_source", FakeReportRenderer);

    pretender.post("/admin/dashboard/reports/bulk", () =>
      response({
        items: [
          {
            source: "test_source",
            identifier: "signups",
            key: "test_source:signups",
            data: { type: "signups", empty: false },
          },
        ],
      })
    );
    pretender.put("/admin/dashboard/reports/layout", () => response(204, {}));

    const item = { ...ITEMS[0], rows: 1, cols: 1 };

    await render(
      <template>
        <DashboardReports @data={{hash items=(array item)}} />
      </template>
    );

    const handle = stubPointerCapture(
      '[data-identifier="test_source:signups"] .db-report__resize-handle'
    ).element;
    await triggerEvent(handle, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });
    await triggerEvent(handle, "pointermove", {
      pointerId: 1,
      clientX: 0,
      clientY: 5000,
    });

    assert
      .dom('[data-identifier="test_source:signups"]')
      .hasClass(
        "--rows-4",
        "an extreme drag stops growing at the maximum row count"
      );
    assert
      .dom('[data-identifier="test_source:signups"]')
      .hasClass("--wide", "and stays forced to the full width along with it");

    await triggerEvent(handle, "pointerup", {
      pointerId: 1,
      clientX: 0,
      clientY: 5000,
    });
  });

  test("clears every card's loading state when the whole bulk request fails", async function (assert) {
    pretender.post("/admin/dashboard/reports/bulk", () => response(500, {}));

    await render(
      <template><DashboardReports @data={{hash items=ITEMS}} /></template>
    );

    assert
      .dom(".db-report__card .loading-container.visible")
      .doesNotExist(
        "no card is left spinning once the whole request has failed"
      );
    assert
      .dom(".db-report__card .db-report__error")
      .exists(
        { count: ITEMS.length },
        "every card shows its own error state instead"
      );
  });
});
