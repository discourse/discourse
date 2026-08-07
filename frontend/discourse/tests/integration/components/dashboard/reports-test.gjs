import { hash } from "@ember/helper";
import { render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardReports from "discourse/admin/components/dashboard/reports";
import { registerAdminDashboardReportRenderer } from "discourse/admin/lib/admin-dashboard-report-renderers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
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

module("Integration | Component | DashboardReports", function (hooks) {
  setupRenderingTest(hooks);

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
