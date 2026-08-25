import { tracked } from "@glimmer/tracking";
import {
  blur,
  click,
  fillIn,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import SimpleList from "discourse/admin/components/simple-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | SimpleList", function (hooks) {
  setupRenderingTest(hooks);

  test("adding a value", async function (assert) {
    const values = "vinkas\nosama";
    await render(<template><SimpleList @values={{values}} /></template>);

    assert.dom(".values .value").exists({ count: 2 });
    assert.dom(".add-value-btn").isDisabled("disabled when input is empty");

    await fillIn(".add-value-input", "penar");
    await click(".add-value-btn");

    assert
      .dom(".values .value")
      .exists({ count: 3 }, "adds the value to the list of values");

    assert
      .dom(".values .value[data-reorderable-key='2'] .value-input")
      .hasValue("penar", "sets the correct value for added item");

    await fillIn(".add-value-input", "eviltrout");
    await triggerKeyEvent(".add-value-input", "keydown", "Enter");

    assert
      .dom(".values .value")
      .exists({ count: 4 }, "adds the value when pressing Enter");
  });

  test("adding a value when list is predefined", async function (assert) {
    const values = "vinkas\nosama";
    const choices = ["vinkas", "osama", "kris", "jeff"];

    await render(
      <template>
        <SimpleList
          @values={{values}}
          @allowAny={{false}}
          @choices={{choices}}
        />
      </template>
    );

    await click(".add-value-input summary");
    assert.dom(".select-kit-row").exists({ count: 2 });
    await click(".select-kit-row");

    assert
      .dom(".values .value")
      .exists({ count: 3 }, "adds the value to the list of values");
  });

  test("changing a value", async function (assert) {
    const done = assert.async();

    const values = "vinkas\nosama";
    const onChange = (collection) => {
      assert.deepEqual(collection, ["vinkas", "jarek"]);
      done();
    };

    await render(
      <template>
        <SimpleList @values={{values}} @onChange={{onChange}} />
      </template>
    );

    await fillIn(
      ".values .value[data-reorderable-key='1'] .value-input",
      "jarek"
    );
    await blur(".values .value[data-reorderable-key='1'] .value-input");

    assert
      .dom(".values .value[data-reorderable-key='1'] .value-input")
      .hasValue("jarek");
  });

  test("removing a value", async function (assert) {
    const values = "vinkas\nosama";
    await render(<template><SimpleList @values={{values}} /></template>);

    await click(
      ".values .value[data-reorderable-key='0'] .d-reorderable-list__remove"
    );

    assert
      .dom(".values .value")
      .exists({ count: 1 }, "removes the value from the list of values");

    assert
      .dom(".values .value[data-reorderable-key='0'] .value-input")
      .hasValue("osama", "removes the correct value");
  });

  test("delimiter support", async function (assert) {
    await render(
      <template>
        <SimpleList @values="vinkas|osama" @inputDelimiter="|" />
      </template>
    );

    await fillIn(".add-value-input", "eviltrout");
    await click(".add-value-btn");

    assert
      .dom(".values .value")
      .exists({ count: 3 }, "adds the value to the list of values");

    assert
      .dom(".values .value[data-reorderable-key='2'] .value-input")
      .hasValue("eviltrout", "adds the correct value");
  });

  test("updates when values change", async function (assert) {
    const state = new (class {
      @tracked values = "vinkas|osama";
    })();

    await render(
      <template>
        <SimpleList @values={{state.values}} @inputDelimiter="|" />
      </template>
    );

    assert
      .dom(".values .value[data-reorderable-key='0'] .value-input")
      .hasValue("vinkas");

    state.values = "kris|jeff";
    await settled();

    assert
      .dom(".values .value[data-reorderable-key='0'] .value-input")
      .hasValue("kris");
  });

  test("a closed set offers no editable field", async function (assert) {
    const choices = ["latest", "new", "unread"];
    const values = "latest|new";

    await render(
      <template>
        <SimpleList
          @values={{values}}
          @inputDelimiter="|"
          @choices={{choices}}
          @allowAny={{false}}
        />
      </template>
    );

    assert
      .dom(".values input.value-input")
      .doesNotExist(
        "a value drawn from a fixed set has nothing to type into it"
      );
    assert
      .dom(".values .value-input.--readonly")
      .exists({ count: 2 }, "each value still reads as its own row");
  });

  test("a free-text list keeps its editable field", async function (assert) {
    const values = "vinkas|osama";

    await render(
      <template><SimpleList @values={{values}} @inputDelimiter="|" /></template>
    );

    assert
      .dom(".values input.value-input")
      .exists(
        { count: 2 },
        "an open list is still edited in place, not only added to"
      );
  });

  test("removing a value names what it removes", async function (assert) {
    const values = "vinkas|osama";

    await render(
      <template><SimpleList @values={{values}} @inputDelimiter="|" /></template>
    );

    assert
      .dom(
        ".values .value[data-reorderable-key='0'] .d-reorderable-list__remove"
      )
      .hasAria(
        "label",
        "Remove vinkas",
        "the standard control says which value it drops"
      );
  });
});
