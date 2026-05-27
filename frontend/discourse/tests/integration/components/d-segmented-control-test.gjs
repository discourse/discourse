import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DSegmentedControl from "discourse/components/d-segmented-control";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import I18n, { i18n } from "discourse-i18n";

module("Integration | Component | d-segmented-control", function (hooks) {
  setupRenderingTest(hooks);

  const ITEMS = [
    { value: "day", label: "Day" },
    { value: "week", label: "Week" },
    { value: "month", label: "Month" },
  ];

  test("renders checked state and updates on click", async function (assert) {
    this.set("selected", "week");
    const handleSelect = (value) => this.set("selected", value);

    await render(
      <template>
        <DSegmentedControl
          @name="period"
          @items={{ITEMS}}
          @value={{this.selected}}
          @onSelect={{handleSelect}}
        />
      </template>
    );

    assert.dom(".d-segmented-control__input[value='day']").isNotChecked();
    assert.dom(".d-segmented-control__input[value='week']").isChecked();
    assert.dom(".d-segmented-control__input[value='month']").isNotChecked();

    await click(".d-segmented-control__label:nth-child(4)");

    assert.dom(".d-segmented-control__input[value='day']").isNotChecked();
    assert.dom(".d-segmented-control__input[value='week']").isNotChecked();
    assert.dom(".d-segmented-control__input[value='month']").isChecked();
  });

  test("@label renders an accessible legend", async function (assert) {
    I18n.translations[I18n.locale].js.test = { periodLabel: "Time period" };

    await render(
      <template>
        <DSegmentedControl
          @name="period"
          @items={{ITEMS}}
          @value="day"
          @label="test.periodLabel"
        />
      </template>
    );

    assert
      .dom(".d-segmented-control__legend")
      .hasText(i18n("test.periodLabel"));
  });

  test("@translatedLabel renders an accessible legend", async function (assert) {
    await render(
      <template>
        <DSegmentedControl
          @name="period"
          @items={{ITEMS}}
          @value="day"
          @translatedLabel="Time period"
        />
      </template>
    );

    assert.dom(".d-segmented-control__legend").hasText("Time period");
  });
});
