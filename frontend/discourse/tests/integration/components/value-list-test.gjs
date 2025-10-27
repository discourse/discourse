import { blur, click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import ValueList from "admin/components/value-list";

module("Integration | Component | value-list", function (hooks) {
  setupRenderingTest(hooks);

  test("adding a value", async function (assert) {
    const self = this;

    this.set("values", "vinkas\nosama");

    await render(<template><ValueList @values={{self.values}} /></template>);

    await selectKit().expand();
    await selectKit().fillInFilter("eviltrout");
    await selectKit().keyboard("Enter");

    assert
      .dom(".values .value")
      .exists({ count: 3 }, "adds the value to the list of values");

    assert.strictEqual(
      this.values,
      "vinkas\nosama\neviltrout",
      "it adds the value to the list of values"
    );
  });

  test("changing a value", async function (assert) {
    const self = this;

    this.set("values", "vinkas\nosama");

    await render(<template><ValueList @values={{self.values}} /></template>);

    await fillIn(".values .value[data-index='1'] .value-input", "jarek");
    await blur(".values .value[data-index='1'] .value-input");

    assert.dom(".values .value[data-index='1'] .value-input").hasValue("jarek");
    assert.deepEqual(this.values, "vinkas\njarek", "updates the value list");
  });

  test("removing a value", async function (assert) {
    const self = this;

    this.set("values", "vinkas\nosama");

    await render(<template><ValueList @values={{self.values}} /></template>);

    await click(".values .value[data-index='0'] .remove-value-btn");

    assert
      .dom(".values .value")
      .exists({ count: 1 }, "removes the value from the list of values");

    assert.strictEqual(this.values, "osama", "it removes the expected value");

    await selectKit().expand();

    assert
      .dom(".select-kit-collection li.select-kit-row span.name")
      .hasText("vinkas", "it adds the removed value to choices");
  });

  test("selecting a value", async function (assert) {
    const self = this;

    this.setProperties({
      values: "vinkas\nosama",
      choices: ["maja", "michael"],
    });

    await render(
      <template>
        <ValueList @values={{self.values}} @choices={{self.choices}} />
      </template>
    );

    await selectKit().expand();
    await selectKit().selectRowByValue("maja");

    assert
      .dom(".values .value")
      .exists({ count: 3 }, "adds the value to the list of values");

    assert.strictEqual(
      this.values,
      "vinkas\nosama\nmaja",
      "it adds the value to the list of values"
    );
  });

  test("array support", async function (assert) {
    const self = this;

    this.set("values", ["vinkas", "osama"]);

    await render(
      <template>
        <ValueList @values={{self.values}} @inputType="array" />
      </template>
    );

    this.set("values", ["vinkas", "osama"]);

    await selectKit().expand();
    await selectKit().fillInFilter("eviltrout");
    await selectKit().selectRowByValue("eviltrout");

    assert
      .dom(".values .value")
      .exists({ count: 3 }, "adds the value to the list of values");

    assert.deepEqual(
      this.values,
      ["vinkas", "osama", "eviltrout"],
      "it adds the value to the list of values"
    );
  });

  test("delimiter support", async function (assert) {
    const self = this;

    this.set("values", "vinkas|osama");

    await render(
      <template>
        <ValueList @values={{self.values}} @inputDelimiter="|" />
      </template>
    );

    await selectKit().expand();
    await selectKit().fillInFilter("eviltrout");
    await selectKit().keyboard("Enter");

    assert
      .dom(".values .value")
      .exists({ count: 3 }, "adds the value to the list of values");

    assert.strictEqual(
      this.values,
      "vinkas|osama|eviltrout",
      "it adds the value to the list of values"
    );
  });
});
