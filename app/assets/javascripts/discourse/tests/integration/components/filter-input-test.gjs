import { hash } from "@ember/helper";
import { fillIn, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import FilterInput from "discourse/components/filter-input";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | FilterInput", function (hooks) {
  setupRenderingTest(hooks);

  test("Left icon", async function (assert) {
    await render(
      <template><FilterInput @icons={{hash left="bell"}} /></template>
    );

    assert.dom(".d-icon-bell.-left").exists();
  });

  test("Right icon", async function (assert) {
    await render(
      <template><FilterInput @icons={{hash right="bell"}} /></template>
    );

    assert.dom(".d-icon-bell.-right").exists();
  });

  test("containerClass argument", async function (assert) {
    await render(<template><FilterInput @containerClass="foo" /></template>);

    assert.dom(".filter-input-container.foo").exists();
  });

  test("Html attributes", async function (assert) {
    await render(
      <template><FilterInput data-foo="1" placeholder="bar" /></template>
    );

    assert.dom('.filter-input[data-foo="1"]').exists();
    assert.dom('.filter-input[placeholder="bar"]').exists();
  });

  test("Filter action", async function (assert) {
    const self = this;

    this.set("value", null);
    this.set("action", (event) => {
      this.set("value", event.target.value);
    });
    await render(
      <template><FilterInput @filterAction={{self.action}} /></template>
    );
    await fillIn(".filter-input", "foo");

    assert.strictEqual(this.value, "foo");
  });

  test("Focused state", async function (assert) {
    const self = this;

    await render(
      <template><FilterInput @filterAction={{self.action}} /></template>
    );
    await triggerEvent(".filter-input", "focusin");

    assert.dom(".filter-input-container.is-focused").exists();

    await triggerEvent(".filter-input", "focusout");

    assert.dom(".filter-input-container.is-focused").doesNotExist();
  });
});
