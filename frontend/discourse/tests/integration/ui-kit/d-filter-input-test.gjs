import { hash } from "@ember/helper";
import { click, fillIn, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DFilterInput from "discourse/ui-kit/d-filter-input";

module("Integration | ui-kit | DFilterInput", function (hooks) {
  setupRenderingTest(hooks);

  test("Left icon", async function (assert) {
    await render(
      <template><DFilterInput @icons={{hash left="bell"}} /></template>
    );

    assert.dom(".d-icon-bell.-left").exists();
  });

  test("Right icon", async function (assert) {
    await render(
      <template><DFilterInput @icons={{hash right="bell"}} /></template>
    );

    assert.dom(".d-icon-bell.-right").exists();
  });

  test("containerClass argument", async function (assert) {
    await render(<template><DFilterInput @containerClass="foo" /></template>);

    assert.dom(".filter-input-container.foo").exists();
  });

  test("Html attributes", async function (assert) {
    await render(
      <template><DFilterInput data-foo="1" placeholder="bar" /></template>
    );

    assert.dom('.filter-input[data-foo="1"]').exists();
    assert.dom('.filter-input[placeholder="bar"]').exists();
  });

  test("Filter action", async function (assert) {
    this.set("value", null);
    this.set("action", (event) => {
      this.set("value", event.target.value);
    });
    await render(
      <template><DFilterInput @filterAction={{this.action}} /></template>
    );
    await fillIn(".filter-input", "foo");

    assert.strictEqual(this.value, "foo");
  });

  test("Focused state", async function (assert) {
    await render(
      <template><DFilterInput @filterAction={{this.action}} /></template>
    );
    await triggerEvent(".filter-input", "focusin");

    assert.dom(".filter-input-container.is-focused").exists();

    await triggerEvent(".filter-input", "focusout");

    assert.dom(".filter-input-container.is-focused").doesNotExist();
  });

  test("Clear button visibility", async function (assert) {
    this.set("clearAction", () => {});
    this.set("value", "test");
    await render(
      <template>
        <DFilterInput
          @onClearInput={{this.clearAction}}
          @value={{this.value}}
        />
      </template>
    );

    assert.dom(".filter-input-clear-btn").exists();

    this.set("value", "");

    assert.dom(".filter-input-clear-btn").doesNotExist();
  });

  test("onClearInput callback", async function (assert) {
    this.set("called", false);
    this.set("clearAction", () => {
      this.set("called", true);
    });
    await render(
      <template>
        <DFilterInput @onClearInput={{this.clearAction}} @value="test" />
      </template>
    );
    await click(".filter-input-clear-btn");

    assert.true(this.called);
  });

  test("Input focus after clear", async function (assert) {
    this.set("clearAction", () => {});
    await render(
      <template>
        <DFilterInput @onClearInput={{this.clearAction}} @value="test" />
      </template>
    );
    await click(".filter-input-clear-btn");

    assert.dom(".filter-input").isFocused();
  });
});
