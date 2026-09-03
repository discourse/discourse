import { fn } from "@ember/helper";
import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import DDateTimeInputRange from "discourse/ui-kit/d-date-time-input-range";

const DEFAULT_DATE_TIME_STRING = "2019-01-29 14:45";
const DEFAULT_DATE_TIME = moment(DEFAULT_DATE_TIME_STRING);

module("Integration | ui-kit | DDateTimeInputRange", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    this.setProperties({ state: { from: DEFAULT_DATE_TIME, to: null } });

    await render(
      <template>
        <DDateTimeInputRange
          @from={{this.state.from}}
          @to={{this.state.to}}
          @onChange={{fn (mut this.state)}}
        />
      </template>
    );

    assert.dom(".from.d-date-time-input .date-picker").hasValue("2019-01-29");
    assert
      .dom(".from.d-date-time-input .d-time-input .combo-box-header")
      .hasAttribute("data-name", "2:45 PM");
    assert.dom(".to.d-date-time-input .date-picker").hasNoValue();
    assert
      .dom(".to.d-date-time-input .d-time-input .combo-box-header")
      .hasAttribute("data-name", "--:--");

    await fillIn(".to.d-date-time-input .date-picker", "2019-01-29");
    const toTimeSelectKit = selectKit(".to .d-time-input .select-kit");
    await toTimeSelectKit.expand();

    let rows = toTimeSelectKit.rows();
    assert.dom(rows[0]).hasAttribute("data-name", "2:45 PM");
    assert.dom(rows[rows.length - 1]).hasAttribute("data-name", "11:45 PM");
    await toTimeSelectKit.collapse();

    await fillIn(".to.d-date-time-input .date-picker", "2019-01-30");
    await toTimeSelectKit.expand();

    rows = toTimeSelectKit.rows();
    assert.dom(rows[0]).hasAttribute("data-name", "12:00 AM");
    assert.dom(rows[rows.length - 1]).hasAttribute("data-name", "11:45 PM");
  });

  test("setting relativeDate results in correct intervals (4x 15m then 30m)", async function (assert) {
    this.setProperties({ state: { from: DEFAULT_DATE_TIME, to: null } });

    await render(
      <template>
        <DDateTimeInputRange
          @from={{this.state.from}}
          @to={{this.state.to}}
          @relativeDate={{this.state.from}}
          @onChange={{fn (mut this.state)}}
        />
      </template>
    );

    await fillIn(".to.d-date-time-input .date-picker", "2019-01-29");
    const toTimeSelectKit = selectKit(".to .d-time-input .select-kit");
    await toTimeSelectKit.expand();

    let rows = toTimeSelectKit.rows();
    assert.dom(rows[4]).hasAttribute("data-name", "3:45 PM");
    assert.dom(rows[5]).hasAttribute("data-name", "4:15 PM");
  });

  test("picking an end equal to start pushes the end an hour later", async function (assert) {
    this.setProperties({
      state: { from: DEFAULT_DATE_TIME, to: moment("2019-01-29 16:45") },
    });

    await render(
      <template>
        <DDateTimeInputRange
          @from={{this.state.from}}
          @to={{this.state.to}}
          @onChange={{fn (mut this.state)}}
        />
      </template>
    );

    const toTimeSelectKit = selectKit(".to .d-time-input .select-kit");
    await toTimeSelectKit.expand();
    await toTimeSelectKit.selectRowByName("2:45 PM");

    assert.strictEqual(
      this.state.to.format("YYYY-MM-DD h:mm A"),
      "2019-01-29 3:45 PM",
      "a zero-length range is not allowed when times are shown"
    );
  });

  test("moving the start onto the end pushes the end an hour later", async function (assert) {
    this.setProperties({
      state: { from: DEFAULT_DATE_TIME, to: moment("2019-01-29 15:45") },
    });

    await render(
      <template>
        <DDateTimeInputRange
          @from={{this.state.from}}
          @to={{this.state.to}}
          @onChange={{fn (mut this.state)}}
        />
      </template>
    );

    const fromTimeSelectKit = selectKit(".from .d-time-input .select-kit");
    await fromTimeSelectKit.expand();
    await fromTimeSelectKit.selectRowByName("3:45 PM");

    assert.strictEqual(
      this.state.from.format("YYYY-MM-DD h:mm A"),
      "2019-01-29 3:45 PM"
    );
    assert.strictEqual(
      this.state.to.format("YYYY-MM-DD h:mm A"),
      "2019-01-29 4:45 PM",
      "the end keeps a positive duration when the start catches up to it"
    );
  });

  test("a single-day range stays intact when times are hidden", async function (assert) {
    this.setProperties({
      state: { from: moment("2019-01-29"), to: null },
    });

    await render(
      <template>
        <DDateTimeInputRange
          @from={{this.state.from}}
          @to={{this.state.to}}
          @onChange={{fn (mut this.state)}}
          @showFromTime={{false}}
          @showToTime={{false}}
        />
      </template>
    );

    await fillIn(".to.d-date-time-input .date-picker", "2019-01-29");

    assert.strictEqual(
      this.state.to.format("YYYY-MM-DD HH:mm"),
      "2019-01-29 00:00",
      "equal boundaries are a valid date-only range"
    );
  });

  test("timezone support", async function (assert) {
    this.setProperties({
      state: {
        from: moment.tz(DEFAULT_DATE_TIME_STRING, "Europe/Paris"),
        to: null,
      },
    });

    await render(
      <template>
        <DDateTimeInputRange
          @from={{this.state.from}}
          @to={{this.state.to}}
          @onChange={{fn (mut this.state)}}
          @timezone="Europe/Paris"
        />
      </template>
    );

    assert.dom(".from.d-date-time-input .date-picker").hasValue("2019-01-29");
    assert
      .dom(".from.d-date-time-input .d-time-input .combo-box-header")
      .hasAttribute("data-name", "2:45 PM");
    assert.dom(".to.d-date-time-input .date-picker").hasNoValue();
    assert
      .dom(".to.d-date-time-input .d-time-input .combo-box-header")
      .hasAttribute("data-name", "--:--");

    await fillIn(".to.d-date-time-input .date-picker", "2019-01-29");
    const toTimeSelectKit = selectKit(".to .d-time-input .select-kit");
    await toTimeSelectKit.expand();
    await toTimeSelectKit.selectRowByName("7:15 PM");

    assert.strictEqual(
      this.state.to.toString(),
      "Tue Jan 29 2019 19:15:00 GMT+0100"
    );
  });
});
