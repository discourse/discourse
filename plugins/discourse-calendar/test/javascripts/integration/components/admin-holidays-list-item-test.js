import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | admin-holidays-list-item", function (hooks) {
  setupRenderingTest(hooks);

  test("when a holiday is disabled, it displays an enable button and adds a disabled CSS class", async function (assert) {
    this.set("holiday", {
      date: "2022-01-01",
      name: "New Year's Day",
      disabled: true,
    });
    this.set("region_code", "sg");

    await render(hbs`
      <AdminHolidaysListItem
        @holiday={{this.holiday}}
        @region_code={{this.region_code}}
        @isHolidayDisabled={{this.holiday.disabled}}
      />
    `);

    assert.dom("button").hasText("Enable", "it displays an enable button");
    assert.dom("tr").hasClass("disabled", "it adds a 'disabled' CSS class");
  });

  test("when a holiday is enabled, it displays a disable button and does not add a disabled CSS class", async function (assert) {
    this.set("holiday", {
      date: "2022-01-01",
      name: "New Year's Day",
      disabled: false,
    });
    this.set("region_code", "au");

    await render(hbs`
      <AdminHolidaysListItem
        @holiday={{this.holiday}}
        @region_code={{this.region_code}}
        @isHolidayDisabled={{this.holiday.disabled}}
      />
    `);

    assert.dom("button").hasText("Disable", "it displays a disable button");
    assert
      .dom("tr")
      .doesNotHaveClass("disabled", "it does not add a 'disabled' CSS class");
  });
});
