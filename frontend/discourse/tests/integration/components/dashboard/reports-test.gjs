import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardReports from "discourse/admin/components/dashboard/reports";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

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
});
