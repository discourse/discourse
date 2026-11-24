import { fn } from "@ember/helper";
import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DDateTimeInputRange from "discourse/ui-kit/d-date-time-input-range";

const DEFAULT_DATE_TIME_STRING = "2019-01-29 14:45";
const DEFAULT_DATE_TIME = moment(DEFAULT_DATE_TIME_STRING);

module("Integration | ui-kit | DDateTimeInputRange", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    this.state = { from: DEFAULT_DATE_TIME, to: null };

    await render(
      <template>
        <DDateTimeInputRange
          @from={{this.state.from}}
          @onChange={{fn (mut this.state)}}
          @to={{this.state.to}}
        />
      </template>
    );

    assert.dom(".from.d-date-time-input .date-picker").hasValue("2019-01-29");
    assert.dom(".from.d-date-time-input .time-input").hasValue("14:45");
    assert.dom(".to.d-date-time-input .date-picker").hasNoValue();
    assert.dom(".to.d-date-time-input .time-input").hasNoValue();
  });

  test("picking an end equal to start pushes the end an hour later", async function (assert) {
    this.state = { from: DEFAULT_DATE_TIME, to: moment("2019-01-29 16:45") };

    await render(
      <template>
        <DDateTimeInputRange
          @from={{this.state.from}}
          @onChange={{fn (mut this.state)}}
          @to={{this.state.to}}
        />
      </template>
    );

    await fillIn(".to.d-date-time-input .time-input", "14:45");

    assert.strictEqual(
      this.state.to.format("YYYY-MM-DD h:mm A"),
      "2019-01-29 3:45 PM",
      "a zero-length range is not allowed when times are shown"
    );
  });

  test("moving the start onto the end pushes the end an hour later", async function (assert) {
    this.state = { from: DEFAULT_DATE_TIME, to: moment("2019-01-29 15:45") };

    await render(
      <template>
        <DDateTimeInputRange
          @from={{this.state.from}}
          @onChange={{fn (mut this.state)}}
          @to={{this.state.to}}
        />
      </template>
    );

    await fillIn(".from.d-date-time-input .time-input", "15:45");

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
    this.state = { from: moment("2019-01-29"), to: null };

    await render(
      <template>
        <DDateTimeInputRange
          @from={{this.state.from}}
          @onChange={{fn (mut this.state)}}
          @showFromTime={{false}}
          @showToTime={{false}}
          @to={{this.state.to}}
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

  test("the to date picker is bounded by the from date", async function (assert) {
    this.state = { from: DEFAULT_DATE_TIME, to: moment("2019-01-30 16:45") };

    await render(
      <template>
        <DDateTimeInputRange
          @from={{this.state.from}}
          @onChange={{fn (mut this.state)}}
          @to={{this.state.to}}
        />
      </template>
    );

    assert
      .dom(".to.d-date-time-input .date-picker")
      .hasAttribute(
        "min",
        "2019-01-29",
        "days before the start are not selectable"
      );
  });

  test("timezone support", async function (assert) {
    this.state = {
      from: moment.tz(DEFAULT_DATE_TIME_STRING, "Europe/Paris"),
      to: null,
    };

    await render(
      <template>
        <DDateTimeInputRange
          @from={{this.state.from}}
          @onChange={{fn (mut this.state)}}
          @timezone="Europe/Paris"
          @to={{this.state.to}}
        />
      </template>
    );

    assert.dom(".from.d-date-time-input .date-picker").hasValue("2019-01-29");
    assert.dom(".from.d-date-time-input .time-input").hasValue("14:45");
    assert.dom(".to.d-date-time-input .date-picker").hasNoValue();
    assert.dom(".to.d-date-time-input .time-input").hasNoValue();

    await fillIn(".to.d-date-time-input .date-picker", "2019-01-29");
    await fillIn(".to.d-date-time-input .time-input", "19:15");

    assert.strictEqual(
      this.state.to.toString(),
      "Tue Jan 29 2019 19:15:00 GMT+0100"
    );
  });

  test("@clearable and @toTimeFirst apply to the end input", async function (assert) {
    await render(
      <template>
        <DDateTimeInputRange
          @clearable={{true}}
          @from={{DEFAULT_DATE_TIME}}
          @to={{DEFAULT_DATE_TIME}}
          @toTimeFirst={{true}}
        />
      </template>
    );

    assert
      .dom(".from .clear-date-time")
      .doesNotExist("the start cannot be cleared");
    assert.dom(".to .clear-date-time").exists("the end can be cleared");
    assert
      .dom(".from > :first-child")
      .hasClass("d-date-input", "the start shows its date first");
    assert
      .dom(".to > :first-child")
      .hasClass("time-input", "the end shows its time first");
  });
});
