import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

function fromDateInput() {
  return query(".from.d-date-time-input .date-picker");
}

function fromTimeInput() {
  return query(".from.d-date-time-input .d-time-input .combo-box-header");
}

function toDateInput() {
  return query(".to.d-date-time-input .date-picker");
}

function toTimeInput() {
  return query(".to.d-date-time-input .d-time-input .combo-box-header");
}

const DEFAULT_DATE_TIME = moment("2019-01-29 14:45");

module("Integration | Component | date-time-input-range", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    this.setProperties({ from: DEFAULT_DATE_TIME, to: null });

    await render(
      hbs`<DateTimeInputRange @from={{this.from}} @to={{this.to}} />`
    );

    assert.strictEqual(fromDateInput().value, "2019-01-29");
    assert.strictEqual(fromTimeInput().dataset.name, "14:45");
    assert.strictEqual(toDateInput().value, "");
    assert.strictEqual(toTimeInput().dataset.name, "--:--");
  });
});
