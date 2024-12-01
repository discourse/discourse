import { fillIn, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

const DEFAULT_DATE_TIME_STRING = "2019-01-29 14:45";
const DEFAULT_DATE_TIME = moment(DEFAULT_DATE_TIME_STRING);

module("Integration | Component | date-time-input-range", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    this.setProperties({ state: { from: DEFAULT_DATE_TIME, to: null } });

    await render(
      hbs`<DateTimeInputRange @from={{this.state.from}} @to={{this.state.to}} @onChange={{fn (mut this.state)}} />`
    );

    assert.dom(".from.d-date-time-input .date-picker").hasValue("2019-01-29");
    assert
      .dom(".from.d-date-time-input .d-time-input .combo-box-header")
      .hasAttribute("data-name", "14:45");
    assert.dom(".to.d-date-time-input .date-picker").hasNoValue();
    assert
      .dom(".to.d-date-time-input .d-time-input .combo-box-header")
      .hasAttribute("data-name", "--:--");

    await fillIn(".to.d-date-time-input .date-picker", "2019-01-29");
    const toTimeSelectKit = selectKit(".to .d-time-input .select-kit");
    await toTimeSelectKit.expand();

    let rows = toTimeSelectKit.rows();
    assert.dom(rows[0]).hasAttribute("data-name", "14:45");
    assert.dom(rows[rows.length - 1]).hasAttribute("data-name", "23:45");
    await toTimeSelectKit.collapse();

    await fillIn(".to.d-date-time-input .date-picker", "2019-01-30");
    await toTimeSelectKit.expand();

    rows = toTimeSelectKit.rows();
    assert.dom(rows[0]).hasAttribute("data-name", "00:00");
    assert.dom(rows[rows.length - 1]).hasAttribute("data-name", "23:45");
  });

  test("setting relativeDate results in correct intervals (4x 15m then 30m)", async function (assert) {
    this.setProperties({ state: { from: DEFAULT_DATE_TIME, to: null } });

    await render(
      hbs`<DateTimeInputRange @from={{this.state.from}} @to={{this.state.to}} @relativeDate={{this.state.from}} @onChange={{fn (mut this.state)}} />`
    );

    await fillIn(".to.d-date-time-input .date-picker", "2019-01-29");
    const toTimeSelectKit = selectKit(".to .d-time-input .select-kit");
    await toTimeSelectKit.expand();

    let rows = toTimeSelectKit.rows();
    assert.dom(rows[4]).hasAttribute("data-name", "15:45");
    assert.dom(rows[5]).hasAttribute("data-name", "16:15");
  });

  test("timezone support", async function (assert) {
    this.setProperties({
      state: {
        from: moment.tz(DEFAULT_DATE_TIME_STRING, "Europe/Paris"),
        to: null,
      },
    });

    await render(
      hbs`<DateTimeInputRange @from={{this.state.from}} @to={{this.state.to}} @onChange={{fn (mut this.state)}} @timezone="Europe/Paris" />`
    );

    assert.dom(".from.d-date-time-input .date-picker").hasValue("2019-01-29");
    assert
      .dom(".from.d-date-time-input .d-time-input .combo-box-header")
      .hasAttribute("data-name", "14:45");
    assert.dom(".to.d-date-time-input .date-picker").hasNoValue();
    assert
      .dom(".to.d-date-time-input .d-time-input .combo-box-header")
      .hasAttribute("data-name", "--:--");

    await fillIn(".to.d-date-time-input .date-picker", "2019-01-29");
    const toTimeSelectKit = selectKit(".to .d-time-input .select-kit");
    await toTimeSelectKit.expand();
    await toTimeSelectKit.selectRowByName("19:15");

    assert.strictEqual(
      this.state.to.toString(),
      "Tue Jan 29 2019 19:15:00 GMT+0100"
    );
  });
});
