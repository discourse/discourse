import {
  blur,
  click,
  fillIn,
  render,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import SimpleList from "admin/components/simple-list";

module("Integration | Component | simple-list", function (hooks) {
  setupRenderingTest(hooks);

  test("adding a value", async function (assert) {
    const self = this;

    this.set("values", "vinkas\nosama");

    await render(<template><SimpleList @values={{self.values}} /></template>);

    assert
      .dom(".add-value-btn[disabled]")
      .exists("while loading the + button is disabled");

    await fillIn(".add-value-input", "penar");
    await click(".add-value-btn");

    assert
      .dom(".values .value")
      .exists({ count: 3 }, "adds the value to the list of values");

    assert
      .dom(".values .value[data-index='2'] .value-input")
      .hasValue("penar", "sets the correct value for added item");

    await fillIn(".add-value-input", "eviltrout");
    await triggerKeyEvent(".add-value-input", "keydown", "Enter");

    assert
      .dom(".values .value")
      .exists({ count: 4 }, "adds the value when keying Enter");
  });

  test("adding a value when list is predefined", async function (assert) {
    const self = this;

    this.set("values", "vinkas\nosama");
    this.set("choices", ["vinkas", "osama", "kris"]);

    await render(
      <template>
        <SimpleList
          @values={{self.values}}
          @allowAny={{false}}
          @choices={{self.choices}}
        />
      </template>
    );

    await click(".add-value-input summary");
    assert.dom(".select-kit-row").exists({ count: 1 });
    await click(".select-kit-row");

    assert
      .dom(".values .value")
      .exists({ count: 3 }, "adds the value to the list of values");
  });

  test("changing a value", async function (assert) {
    const self = this;

    const done = assert.async();

    this.set("values", "vinkas\nosama");
    this.set("onChange", function (collection) {
      assert.deepEqual(collection, ["vinkas", "jarek"]);
      done();
    });

    await render(
      <template>
        <SimpleList @values={{self.values}} @onChange={{self.onChange}} />
      </template>
    );

    await fillIn(".values .value[data-index='1'] .value-input", "jarek");
    await blur(".values .value[data-index='1'] .value-input");

    assert.dom(".values .value[data-index='1'] .value-input").hasValue("jarek");
  });

  test("removing a value", async function (assert) {
    const self = this;

    this.set("values", "vinkas\nosama");

    await render(<template><SimpleList @values={{self.values}} /></template>);

    await click(".values .value[data-index='0'] .remove-value-btn");

    assert
      .dom(".values .value")
      .exists({ count: 1 }, "removes the value from the list of values");

    assert
      .dom(".values .value[data-index='0'] .value-input")
      .hasValue("osama", "removes the correct value");
  });

  test("delimiter support", async function (assert) {
    const self = this;

    this.set("values", "vinkas|osama");

    await render(
      <template>
        <SimpleList @values={{self.values}} @inputDelimiter="|" />
      </template>
    );

    await fillIn(".add-value-input", "eviltrout");
    await click(".add-value-btn");

    assert
      .dom(".values .value")
      .exists({ count: 3 }, "adds the value to the list of values");

    assert
      .dom(".values .value[data-index='2'] .value-input")
      .hasValue("eviltrout", "adds the correct value");
  });
});
