import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | admin-holidays-list", function (hooks) {
  setupRenderingTest(hooks);

  test("displaying a list of the provided holidays", async function (assert) {
    this.set("holidays", [
      { date: "2022-01-01", name: "New Year's Day" },
      { date: "2022-01-17", name: "Martin Luther King, Jr. Day" },
    ]);

    await render(hbs`<AdminHolidaysList @holidays={{this.holidays}} />`);

    assert
      .dom("table tbody tr:nth-child(1) td:nth-child(1)")
      .hasText("2022-01-01", "it displays the first holiday date");
    assert
      .dom("table tbody tr:nth-child(1) td:nth-child(2)")
      .hasText("New Year's Day", "it displays the first holiday name");

    assert
      .dom("table tbody tr:nth-child(2) td:nth-child(1)")
      .hasText("2022-01-17", "it displays the second holiday date");
    assert
      .dom("table tbody tr:nth-child(2) td:nth-child(2)")
      .hasText(
        "Martin Luther King, Jr. Day",
        "it displays the second holiday name"
      );
  });
});
