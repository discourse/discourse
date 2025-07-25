import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AdminHolidaysListItem from "discourse/plugins/discourse-calendar/discourse/components/admin-holidays-list-item";

module("Integration | Component | admin-holidays-list-item", function (hooks) {
  setupRenderingTest(hooks);

  test("when a holiday is disabled, it displays an enable button and adds a disabled CSS class", async function (assert) {
    const self = this;

    this.set("holiday", {
      date: "2022-01-01",
      name: "New Year's Day",
      disabled: true,
    });
    this.set("region_code", "sg");

    await render(
      <template>
        <AdminHolidaysListItem
          @holiday={{self.holiday}}
          @region_code={{self.region_code}}
          @isHolidayDisabled={{self.holiday.disabled}}
        />
      </template>
    );

    assert.dom("button").hasText("Enable", "it displays an enable button");
    assert.dom("tr").hasClass("disabled", "it adds a 'disabled' CSS class");
  });

  test("when a holiday is enabled, it displays a disable button and does not add a disabled CSS class", async function (assert) {
    const self = this;

    this.set("holiday", {
      date: "2022-01-01",
      name: "New Year's Day",
      disabled: false,
    });
    this.set("region_code", "au");

    await render(
      <template>
        <AdminHolidaysListItem
          @holiday={{self.holiday}}
          @region_code={{self.region_code}}
          @isHolidayDisabled={{self.holiday.disabled}}
        />
      </template>
    );

    assert.dom("button").hasText("Disable", "it displays a disable button");
    assert
      .dom("tr")
      .doesNotHaveClass("disabled", "it does not add a 'disabled' CSS class");
  });
});
