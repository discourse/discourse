import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { fillIn, render } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import selectKit from "discourse/tests/helpers/select-kit-helper";

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

const DEFAULT_DATE_TIME_STRING = "2019-01-29 14:45";
const DEFAULT_DATE_TIME = moment(DEFAULT_DATE_TIME_STRING);

module("Integration | Component | date-time-input-range", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    this.setProperties({ state: { from: DEFAULT_DATE_TIME, to: null } });

    await render(
      hbs`<DateTimeInputRange @from={{this.state.from}} @to={{this.state.to}} @onChange={{action (mut this.state)}} />`
    );

    assert.strictEqual(fromDateInput().value, "2019-01-29");
    assert.strictEqual(fromTimeInput().dataset.name, "14:45");
    assert.strictEqual(toDateInput().value, "");
    assert.strictEqual(toTimeInput().dataset.name, "--:--");

    await fillIn(toDateInput(), "2019-01-29");
    const toTimeSelectKit = selectKit(".to .d-time-input .select-kit");
    await toTimeSelectKit.expand();
    let rows = toTimeSelectKit.rows();
    assert.equal(rows[0].dataset.name, "14:45");
    assert.equal(rows[rows.length - 1].dataset.name, "23:45");
    await toTimeSelectKit.collapse();

    await fillIn(toDateInput(), "2019-01-30");
    await toTimeSelectKit.expand();
    rows = toTimeSelectKit.rows();

    assert.equal(rows[0].dataset.name, "00:00");
    assert.equal(rows[rows.length - 1].dataset.name, "23:45");
  });

  test("timezone support", async function (assert) {
    this.setProperties({
      state: {
        from: moment.tz(DEFAULT_DATE_TIME_STRING, "Europe/Paris"),
        to: null,
      },
    });

    await render(
      hbs`<DateTimeInputRange @from={{this.state.from}} @to={{this.state.to}} @onChange={{action (mut this.state)}} @timezone="Europe/Paris" />`
    );

    assert.strictEqual(fromDateInput().value, "2019-01-29");
    assert.strictEqual(fromTimeInput().dataset.name, "14:45");
    assert.strictEqual(toDateInput().value, "");
    assert.strictEqual(toTimeInput().dataset.name, "--:--");

    await fillIn(toDateInput(), "2019-01-29");
    const toTimeSelectKit = selectKit(".to .d-time-input .select-kit");
    await toTimeSelectKit.expand();
    await toTimeSelectKit.selectRowByName("19:15");

    assert.equal(this.state.to.toString(), "Tue Jan 29 2019 19:15:00 GMT+0100");
  });
});
