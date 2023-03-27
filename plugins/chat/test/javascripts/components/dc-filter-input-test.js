import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { fillIn, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";

module("Discourse Chat | Component | dc-filter-input", function (hooks) {
  setupRenderingTest(hooks);

  test("Left icon", async function (assert) {
    await render(hbs`<DcFilterInput @icons={{hash left="bell"}} />`);

    assert.true(exists(".d-icon-bell.-left"));
  });

  test("Right icon", async function (assert) {
    await render(hbs`<DcFilterInput @icons={{hash right="bell"}} />`);

    assert.true(exists(".d-icon-bell.-right"));
  });

  test("Class attribute", async function (assert) {
    await render(hbs`<DcFilterInput @class="foo" />`);

    assert.true(exists(".dc-filter-input-container.foo"));
  });

  test("Html attributes", async function (assert) {
    await render(hbs`<DcFilterInput data-foo="1" placeholder="bar" />`);

    assert.true(exists('.dc-filter-input[data-foo="1"]'));
    assert.true(exists('.dc-filter-input[placeholder="bar"]'));
  });

  test("Filter action", async function (assert) {
    this.set("value", null);
    this.set("action", (event) => {
      this.set("value", event.target.value);
    });
    await render(hbs`<DcFilterInput @filterAction={{this.action}} />`);
    await fillIn(".dc-filter-input", "foo");

    assert.strictEqual(this.value, "foo");
  });

  test("Focused state", async function (assert) {
    await render(hbs`<DcFilterInput @filterAction={{this.action}} />`);
    await triggerEvent(".dc-filter-input", "focusin");

    assert.true(exists(".dc-filter-input-container.is-focused"));

    await triggerEvent(".dc-filter-input", "focusout");

    assert.false(exists(".dc-filter-input-container.is-focused"));
  });
});
