import { hash } from "@ember/helper";
import { fillIn, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import FilterInput from "discourse/components/filter-input";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | filter-input", function (hooks) {
  setupRenderingTest(hooks);

  test("Left icon", async function (assert) {
    await render(
      <template><FilterInput @icons={{hash left="bell"}} /></template>
    );

    assert.true(exists(".d-icon-bell.-left"));
  });

  test("Right icon", async function (assert) {
    await render(
      <template><FilterInput @icons={{hash right="bell"}} /></template>
    );

    assert.true(exists(".d-icon-bell.-right"));
  });

  test("containerClass argument", async function (assert) {
    await render(<template><FilterInput @containerClass="foo" /></template>);

    assert.true(exists(".filter-input-container.foo"));
  });

  test("Html attributes", async function (assert) {
    await render(
      <template><FilterInput data-foo="1" placeholder="bar" /></template>
    );

    assert.true(exists('.filter-input[data-foo="1"]'));
    assert.true(exists('.filter-input[placeholder="bar"]'));
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

    assert.true(exists(".filter-input-container.is-focused"));

    await triggerEvent(".filter-input", "focusout");

    assert.false(exists(".filter-input-container.is-focused"));
  });
});
