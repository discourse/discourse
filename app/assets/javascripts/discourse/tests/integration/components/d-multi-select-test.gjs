import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import {
  click,
  fillIn,
  render,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import DMultiSelect from "discourse/components/d-multi-select";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

class TestComponent extends Component {
  @tracked selection = this.args.selection ?? [];

  @action
  onChange(newSelection) {
    this.selection = newSelection;
  }

  @action
  async loadFn(filter) {
    return [
      { id: 1, name: "foo" },
      { id: 2, name: "bar" },
    ].filter((item) => {
      return item.name.toLowerCase().includes(filter.toLowerCase());
    });
  }

  <template>
    <DMultiSelect
      @loadFn={{if @loadFn @loadFn this.loadFn}}
      @compareFn={{@compareFn}}
      @onChange={{this.onChange}}
      @selection={{this.selection}}
      @label={{@label}}
    >
      <:selection as |result|>{{result.name}}</:selection>
      <:result as |result|>{{result.name}}</:result>
      <:error as |error|>{{error}}</:error>
    </DMultiSelect>
  </template>
}

module("Integration | Component | d-multi-select", function (hooks) {
  setupRenderingTest(hooks);

  test("filter", async function (assert) {
    await render(<template><TestComponent /></template>);

    await click(".d-multi-select-trigger");
    await fillIn(".d-multi-select__search-input", "bar");

    assert.dom(".d-multi-select__result:nth-child(1)").hasText("bar");
    assert.dom(".d-multi-select__result:nth-child(2)").doesNotExist();
  });

  test("@selection", async function (assert) {
    const selection = [{ id: 1, name: "foo" }];

    await render(
      <template><TestComponent @selection={{selection}} /></template>
    );

    assert
      .dom(".d-multi-select-trigger__selected-item:nth-child(1)")
      .hasText("foo");
    assert
      .dom(".d-multi-select-trigger__selected-item:nth-child(2)")
      .doesNotExist();
  });

  test("@onChange", async function (assert) {
    await render(<template><TestComponent /></template>);
    await click(".d-multi-select-trigger");
    await click(".d-multi-select__result:nth-child(1)");
    await click(".d-multi-select__result:nth-child(2)");

    assert
      .dom(".d-multi-select-trigger__selected-item:nth-child(1)")
      .hasText("foo");
    assert
      .dom(".d-multi-select-trigger__selected-item:nth-child(2)")
      .hasText("bar");
  });

  test("keyboard", async function (assert) {
    await render(<template><TestComponent /></template>);
    await click(".d-multi-select-trigger");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");

    assert
      .dom(".d-multi-select__result:nth-child(1)")
      .hasClass("--preselected");

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowUp");

    assert
      .dom(".d-multi-select__result:nth-child(1)")
      .hasClass("--preselected");

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");

    assert
      .dom(".d-multi-select__result:nth-child(2)")
      .hasClass("--preselected");

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");

    assert
      .dom(".d-multi-select__result:nth-child(2)")
      .hasClass("--preselected");

    await triggerKeyEvent(document.activeElement, "keydown", "Enter");

    assert
      .dom(".d-multi-select-trigger__selected-item:nth-child(1)")
      .hasText("bar");
  });

  test("@compareFn", async function (assert) {
    const compareFn = (a, b) => {
      return a.name === b.name;
    };

    const loadFn = async () => {
      return [{ name: "foo" }, { name: "bar" }];
    };

    await render(
      <template>
        <TestComponent @compareFn={{compareFn}} @loadFn={{loadFn}} />
      </template>
    );

    await click(".d-multi-select-trigger");
    await click(".d-multi-select__result:nth-child(1)");
    await click(".d-multi-select__result:nth-child(2)");

    assert
      .dom(".d-multi-select-trigger__selected-item:nth-child(1)")
      .hasText("foo");
    assert
      .dom(".d-multi-select-trigger__selected-item:nth-child(2)")
      .hasText("bar");
  });

  test("@label", async function (assert) {
    await render(<template><TestComponent @label="label" /></template>);

    assert.dom(".d-multi-select-trigger__label").hasText("label");
  });

  test("@loadFn", async function (assert) {
    const loadFn = async () => {
      return [
        { id: 1, name: "cat" },
        { id: 2, name: "dog" },
      ];
    };

    await render(<template><TestComponent @loadFn={{loadFn}} /></template>);

    await click(".d-multi-select-trigger");

    assert.dom(".d-multi-select__result:nth-child(1)").hasText("cat");
    assert.dom(".d-multi-select__result:nth-child(2)").hasText("dog");
  });

  test("select item", async function (assert) {
    await render(<template><TestComponent /></template>);
    await click(".d-multi-select-trigger");
    await click(".d-multi-select__result:nth-child(1)");
    await click(".d-multi-select__result:nth-child(2)");

    assert
      .dom(".d-multi-select-trigger__selected-item:nth-child(1)")
      .hasText("foo");
    assert
      .dom(".d-multi-select-trigger__selected-item:nth-child(2)")
      .hasText("bar");
  });

  test("unselect item", async function (assert) {
    await render(<template><TestComponent /></template>);
    await click(".d-multi-select-trigger");
    await click(".d-multi-select__result:nth-child(1)");
    await click(".d-multi-select__result:nth-child(2)");
    await click(".d-multi-select-trigger__selected-item:nth-child(1)");

    assert
      .dom(".d-multi-select-trigger__selected-item:nth-child(1)")
      .hasText("bar");
    assert
      .dom(".d-multi-select-trigger__selected-item:nth-child(2)")
      .doesNotExist();
  });

  test("preselect item", async function (assert) {
    await render(<template><TestComponent /></template>);
    await click(".d-multi-select-trigger");
    await triggerEvent(".d-multi-select__result:nth-child(1)", "mouseenter");

    assert
      .dom(".d-multi-select__result:nth-child(1)")
      .hasClass("--preselected");
  });

  test(":error", async function (assert) {
    const loadFn = async () => {
      throw new Error("error");
    };

    await render(<template><TestComponent @loadFn={{loadFn}} /></template>);
    await click(".d-multi-select-trigger");

    assert.dom(".d-multi-select__error").hasText("Error: error");
  });
});
