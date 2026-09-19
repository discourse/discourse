import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardSkeleton from "discourse/admin/components/dashboard/skeleton";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | Dashboard | Skeleton", function (hooks) {
  setupRenderingTest(hooks);

  test("renders an accessible status wrapper", async function (assert) {
    await render(<template><DashboardSkeleton /></template>);

    assert
      .dom(".db-skeleton")
      .hasAttribute("role", "status")
      .hasAria("label", i18n("admin.dashboard.loading"));
  });

  test("renders placeholder blocks for all four dashboard sections", async function (assert) {
    await render(<template><DashboardSkeleton /></template>);

    assert.dom(".db-skeleton__highlights").exists();
    assert.dom(".db-skeleton__reports").exists();
    assert.dom(".db-skeleton__traffic").exists();
    assert.dom(".db-skeleton__engagement").exists();
  });

  test("renders four KPI placeholders and four report cards", async function (assert) {
    await render(<template><DashboardSkeleton /></template>);

    assert.dom(".db-skeleton__kpi").exists({ count: 4 });
    assert.dom(".db-skeleton__report-card").exists({ count: 4 });
  });

  test("opts into the shimmer animation", async function (assert) {
    await render(<template><DashboardSkeleton /></template>);

    assert.dom(".db-skeleton").hasClass("--animation");
  });
});
