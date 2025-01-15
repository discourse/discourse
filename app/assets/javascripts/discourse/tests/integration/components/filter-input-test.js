import { fillIn, render, triggerEvent } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | filter-input", function (hooks) {
  setupRenderingTest(hooks);

  test("Left icon", async function (assert) {
    await render(hbs`<FilterInput @icons={{hash left="bell"}} />`);

    assert.true(exists(".d-icon-bell.-left"));
  });

  test("Right icon", async function (assert) {
    await render(hbs`<FilterInput @icons={{hash right="bell"}} />`);

    assert.true(exists(".d-icon-bell.-right"));
  });

  test("containerClass argument", async function (assert) {
    await render(hbs`<FilterInput @containerClass="foo" />`);

    assert.true(exists(".filter-input-container.foo"));
  });

  test("Html attributes", async function (assert) {
    await render(hbs`<FilterInput data-foo="1" placeholder="bar" />`);

    assert.true(exists('.filter-input[data-foo="1"]'));
    assert.true(exists('.filter-input[placeholder="bar"]'));
  });

  test("Filter action", async function (assert) {
    this.set("value", null);
    this.set("action", (event) => {
      this.set("value", event.target.value);
    });
    await render(hbs`<FilterInput @filterAction={{this.action}} />`);
    await fillIn(".filter-input", "foo");

    assert.strictEqual(this.value, "foo");
  });

  test("Focused state", async function (assert) {
    await render(hbs`<FilterInput @filterAction={{this.action}} />`);
    await triggerEvent(".filter-input", "focusin");

    assert.true(exists(".filter-input-container.is-focused"));

    await triggerEvent(".filter-input", "focusout");

    assert.false(exists(".filter-input-container.is-focused"));
  });
});
