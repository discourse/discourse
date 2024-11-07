import { fillIn, render, triggerEvent } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";

module("Discourse Chat | Component | dc-filter-input", function (hooks) {
  setupRenderingTest(hooks);

  test("Left icon", async function (assert) {
    await render(hbs`<DcFilterInput @icons={{hash left="bell"}} />`);

    assert.dom(".d-icon-bell.-left").exists();
  });

  test("Right icon", async function (assert) {
    await render(hbs`<DcFilterInput @icons={{hash right="bell"}} />`);

    assert.dom(".d-icon-bell.-right").exists();
  });

  test("containerClass argument", async function (assert) {
    await render(hbs`<DcFilterInput @containerClass="foo" />`);

    assert.dom(".dc-filter-input-container.foo").exists();
  });

  test("Html attributes", async function (assert) {
    await render(hbs`<DcFilterInput data-foo="1" placeholder="bar" />`);

    assert.dom('.dc-filter-input[data-foo="1"]').exists();
    assert.dom('.dc-filter-input[placeholder="bar"]').exists();
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

    assert.dom(".dc-filter-input-container.is-focused").exists();

    await triggerEvent(".dc-filter-input", "focusout");

    assert.false(exists(".dc-filter-input-container.is-focused"));
  });
});
