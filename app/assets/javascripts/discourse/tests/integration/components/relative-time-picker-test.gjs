import { tracked } from "@glimmer/tracking";
import { fillIn, render, settled, typeIn } from "@ember/test-helpers";
import { module, test } from "qunit";
import RelativeTimePicker from "discourse/components/relative-time-picker";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | relative-time-picker", function (hooks) {
  setupRenderingTest(hooks);

  test("calls the onChange arg", async function (assert) {
    let updatedValue;
    const update = (value) => (updatedValue = value);
    await render(<template>
      <RelativeTimePicker @onChange={{update}} />
    </template>);

    // empty and "minutes" by default
    assert.dom(".relative-time-duration").hasValue("");
    assert.strictEqual(
      selectKit().header().value(),
      "mins",
      "dropdown has 'minutes' preselected"
    );

    // type <60 minutes
    await typeIn(".relative-time-duration", "50");
    assert.dom(".relative-time-duration").hasValue("50");
    assert.strictEqual(updatedValue, 50, "onChange called with 50");

    // select "hours"
    await selectKit().expand();
    await selectKit().selectRowByValue("hours");
    assert.dom(".relative-time-duration").hasValue("50");
    assert.strictEqual(updatedValue, 50 * 60, "onChange called with 50 * 60");

    // clear the duration
    await fillIn(".relative-time-duration", "");
    assert.dom(".relative-time-duration").hasValue("");
    assert.strictEqual(updatedValue, null, "onChange called with null");
    assert.strictEqual(
      selectKit().header().value(),
      "hours",
      "dropdown has 'hours' selected"
    );

    // type a new value
    await typeIn(".relative-time-duration", "22");
    assert.strictEqual(
      selectKit().header().value(),
      "hours",
      "dropdown has still 'hours' selected"
    );
    assert.dom(".relative-time-duration").hasValue("22");
    assert.strictEqual(updatedValue, 22 * 60, "onChange called with 22 * 60");

    // select "minutes"
    await selectKit().expand();
    await selectKit().selectRowByValue("mins");
    assert.dom(".relative-time-duration").hasValue("22");
    assert.strictEqual(updatedValue, 22, "onChange called with 22");

    // type >60 minutes
    await fillIn(".relative-time-duration", "");
    await typeIn(".relative-time-duration", "800");
    assert.dom(".relative-time-duration").hasValue("13.5");
    assert.strictEqual(updatedValue, 800, "onChange called with 800");
    assert.strictEqual(
      selectKit().header().value(),
      "hours",
      "automatically changes the dropdown to 'hours'"
    );
  });

  test("onChange callback works w/ a start value", async function (assert) {
    const testState = new (class {
      @tracked minutes = 120;
    })();

    const update = (value) => (testState.minutes = value);
    await render(<template>
      <RelativeTimePicker
        @onChange={{update}}
        @durationMinutes={{testState.minutes}}
      />
    </template>);

    // uses the value and selects the right interval
    assert.dom(".relative-time-duration").hasValue("2");
    assert.strictEqual(
      selectKit().header().value(),
      "hours",
      "dropdown has 'hours' preselected"
    );

    // clear the duration
    await fillIn(".relative-time-duration", "");
    assert.dom(".relative-time-duration").hasValue("");
    assert.strictEqual(testState.minutes, null, "onChange called with null");
    // semi-acceptable behavior: because `initValues()` is called, it changes the interval:
    assert.strictEqual(
      selectKit().header().value(),
      "mins",
      "dropdown has 'minutes' selected"
    );

    // type <60 minutes
    await typeIn(".relative-time-duration", "18");
    assert.dom(".relative-time-duration").hasValue("18");
    assert.strictEqual(testState.minutes, 18, "onChange called with 18");

    // select "days"
    await selectKit().expand();
    await selectKit().selectRowByValue("days");
    assert.dom(".relative-time-duration").hasValue("18");
    assert.strictEqual(
      testState.minutes,
      18 * 60 * 24,
      "onChange called with 18 * 60 * 24"
    );

    // type a new value
    await fillIn(".relative-time-duration", "2");
    assert.strictEqual(
      selectKit().header().value(),
      "days",
      "dropdown has still 'days' selected"
    );
    assert.dom(".relative-time-duration").hasValue("2");
    assert.strictEqual(
      testState.minutes,
      2 * 60 * 24,
      "onChange called with 2 * 60 * 24"
    );

    // select "minutes"
    await selectKit().expand();
    await selectKit().selectRowByValue("mins");
    assert.dom(".relative-time-duration").hasValue("2");
    assert.strictEqual(testState.minutes, 2, "onChange called with 2");

    // type >60 minutes
    await fillIn(".relative-time-duration", "90");
    assert.dom(".relative-time-duration").hasValue("1.5");
    assert.strictEqual(testState.minutes, 90, "onChange called with 90");
    assert.strictEqual(
      selectKit().header().value(),
      "hours",
      "automatically changes the dropdown to 'hours'"
    );
  });

  test("updates the input when args change", async function (assert) {
    const testState = new (class {
      @tracked value;
    })();
    testState.value = 10;

    await render(<template>
      <RelativeTimePicker @durationMinutes={{testState.value}} />
    </template>);

    assert.strictEqual(selectKit().header().value(), "mins");
    assert.dom(".relative-time-duration").hasValue("10");

    testState.value = 20;
    await settled();

    assert.dom(".relative-time-duration").hasValue("20");
  });

  test("prefills and preselects minutes", async function (assert) {
    await render(<template>
      <RelativeTimePicker @durationMinutes="5" />
    </template>);

    assert.strictEqual(selectKit().header().value(), "mins");
    assert.dom(".relative-time-duration").hasValue("5");
  });

  test("prefills and preselects null minutes", async function (assert) {
    await render(<template>
      <RelativeTimePicker @durationMinutes={{null}} />
    </template>);

    assert.strictEqual(selectKit().header().value(), "mins");
    assert.dom(".relative-time-duration").hasValue("");
  });

  test("prefills and preselects hours based on converted minutes", async function (assert) {
    await render(<template>
      <RelativeTimePicker @durationMinutes="90" />
    </template>);

    assert.strictEqual(selectKit().header().value(), "hours");
    assert.dom(".relative-time-duration").hasValue("1.5");
  });

  test("prefills and preselects days based on converted minutes", async function (assert) {
    await render(<template>
      <RelativeTimePicker @durationMinutes="2880" />
    </template>);

    assert.strictEqual(selectKit().header().value(), "days");
    assert.dom(".relative-time-duration").hasValue("2");
  });

  test("prefills and preselects months based on converted minutes", async function (assert) {
    await render(<template>
      <RelativeTimePicker @durationMinutes="151200" />
    </template>);

    assert.strictEqual(selectKit().header().value(), "months");
    assert.dom(".relative-time-duration").hasValue("3.5");
  });

  test("prefills and preselects years based on converted minutes", async function (assert) {
    await render(<template>
      <RelativeTimePicker @durationMinutes="525700" />
    </template>);

    assert.strictEqual(selectKit().header().value(), "years");
    assert.dom(".relative-time-duration").hasValue("1");
  });

  test("prefills and preselects hours", async function (assert) {
    await render(<template>
      <RelativeTimePicker @durationHours="5" />
    </template>);

    assert.strictEqual(selectKit().header().value(), "hours");
    assert.dom(".relative-time-duration").hasValue("5");
  });

  test("prefills and preselects null hours", async function (assert) {
    await render(<template>
      <RelativeTimePicker @durationHours={{null}} />
    </template>);

    assert.strictEqual(selectKit().header().value(), "hours");
    assert.dom(".relative-time-duration").hasValue("");
  });

  test("prefills and preselects minutes based on converted hours", async function (assert) {
    await render(<template>
      <RelativeTimePicker @durationHours="0.5" />
    </template>);

    assert.strictEqual(selectKit().header().value(), "mins");
    assert.dom(".relative-time-duration").hasValue("30");
  });

  test("prefills and preselects days based on converted hours", async function (assert) {
    await render(<template>
      <RelativeTimePicker @durationHours="48" />
    </template>);

    assert.strictEqual(selectKit().header().value(), "days");
    assert.dom(".relative-time-duration").hasValue("2");
  });

  test("prefills and preselects months based on converted hours", async function (assert) {
    await render(<template>
      <RelativeTimePicker @durationHours="2160" />
    </template>);

    assert.strictEqual(selectKit().header().value(), "months");
    assert.dom(".relative-time-duration").hasValue("3");
  });

  test("prefills and preselects years based on converted hours", async function (assert) {
    await render(<template>
      <RelativeTimePicker @durationHours="17520" />
    </template>);

    assert.strictEqual(selectKit().header().value(), "years");
    assert.dom(".relative-time-duration").hasValue("2");
  });
});
