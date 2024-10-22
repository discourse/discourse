import {
  blur,
  click,
  fillIn,
  render,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { count, query } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | simple-list", function (hooks) {
  setupRenderingTest(hooks);

  test("adding a value", async function (assert) {
    this.set("values", "vinkas\nosama");

    await render(hbs`<SimpleList @values={{this.values}} />`);

    assert
      .dom(".add-value-btn[disabled]")
      .exists("while loading the + button is disabled");

    await fillIn(".add-value-input", "penar");
    await click(".add-value-btn");

    assert.strictEqual(
      count(".values .value"),
      3,
      "it adds the value to the list of values"
    );

    assert.strictEqual(
      query(".values .value[data-index='2'] .value-input").value,
      "penar",
      "it sets the correct value for added item"
    );

    await fillIn(".add-value-input", "eviltrout");
    await triggerKeyEvent(".add-value-input", "keydown", "Enter");

    assert.strictEqual(
      count(".values .value"),
      4,
      "it adds the value when keying Enter"
    );
  });

  test("adding a value when list is predefined", async function (assert) {
    this.set("values", "vinkas\nosama");
    this.set("choices", ["vinkas", "osama", "kris"]);

    await render(
      hbs`<SimpleList @values={{this.values}} @allowAny={{false}} @choices={{this.choices}}/>`
    );

    await click(".add-value-input summary");
    assert.strictEqual(count(".select-kit-row"), 1);
    await click(".select-kit-row");

    assert.strictEqual(
      count(".values .value"),
      3,
      "it adds the value to the list of values"
    );
  });

  test("changing a value", async function (assert) {
    const done = assert.async();

    this.set("values", "vinkas\nosama");
    this.set("onChange", function (collection) {
      assert.deepEqual(collection, ["vinkas", "jarek"]);
      done();
    });

    await render(
      hbs`<SimpleList @values={{this.values}} @onChange={{this.onChange}} />`
    );

    await fillIn(".values .value[data-index='1'] .value-input", "jarek");
    await blur(".values .value[data-index='1'] .value-input");

    assert.strictEqual(
      query(".values .value[data-index='1'] .value-input").value,
      "jarek"
    );
  });

  test("removing a value", async function (assert) {
    this.set("values", "vinkas\nosama");

    await render(hbs`<SimpleList @values={{this.values}} />`);

    await click(".values .value[data-index='0'] .remove-value-btn");

    assert.strictEqual(
      count(".values .value"),
      1,
      "it removes the value from the list of values"
    );

    assert.strictEqual(
      query(".values .value[data-index='0'] .value-input").value,
      "osama",
      "it removes the correct value"
    );
  });

  test("delimiter support", async function (assert) {
    this.set("values", "vinkas|osama");

    await render(
      hbs`<SimpleList @values={{this.values}} @inputDelimiter="|" />`
    );

    await fillIn(".add-value-input", "eviltrout");
    await click(".add-value-btn");

    assert.strictEqual(
      count(".values .value"),
      3,
      "it adds the value to the list of values"
    );

    assert.strictEqual(
      query(".values .value[data-index='2'] .value-input").value,
      "eviltrout",
      "it adds the correct value"
    );
  });
});
