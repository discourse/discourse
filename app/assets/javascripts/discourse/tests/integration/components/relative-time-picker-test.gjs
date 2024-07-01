import { tracked } from "@glimmer/tracking";
import { render, settled, typeIn } from "@ember/test-helpers";
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

    assert.strictEqual(selectKit().header().value(), "mins");
    assert.dom(".relative-time-duration").hasValue("");

    await typeIn(".relative-time-duration", "50");
    assert.dom(".relative-time-duration").hasValue("50");
    assert.strictEqual(updatedValue, 50);

    await selectKit().expand();
    await selectKit().selectRowByValue("hours");
    assert.dom(".relative-time-duration").hasValue("50");
    assert.strictEqual(updatedValue, 50 * 60);

    await typeIn(".relative-time-duration", "30");
    assert.strictEqual(selectKit().header().value(), "hours");
    assert.dom(".relative-time-duration").hasValue("30");
    assert.strictEqual(updatedValue, 30 * 60);

    await selectKit().expand();
    await selectKit().selectRowByValue("mins");
    assert.dom(".relative-time-duration").hasValue("30");
    assert.strictEqual(updatedValue, 30);
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
      <RelativeTimePicker @durationMinutes="129600" />
    </template>);

    assert.strictEqual(selectKit().header().value(), "months");
    assert.dom(".relative-time-duration").hasValue("3");
  });

  test("prefills and preselects years based on converted minutes", async function (assert) {
    await render(<template>
      <RelativeTimePicker @durationMinutes="525600" />
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
