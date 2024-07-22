import { render, settled } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Helper | document-class", function (hooks) {
  setupRenderingTest(hooks);

  test("A single class", async function (assert) {
    await render(hbs`{{document-class "foo"}}`);

    assert.true(document.documentElement.classList.contains("foo"));
  });

  test("Multiple classes", async function (assert) {
    this.set("bar", "bar");
    await render(hbs`{{document-class "baz" this.bar}}`);

    assert.true(document.documentElement.classList.contains("baz"));
    assert.true(document.documentElement.classList.contains("bar"));
  });

  test("Empty classes", async function (assert) {
    const classesBefore = document.documentElement.className;
    await render(hbs`{{document-class (if false "not-really")}}`);
    assert.strictEqual(document.documentElement.className, classesBefore);
  });

  test("Dynamic classes", async function (assert) {
    this.set("dynamic", "bar");
    await render(hbs`{{document-class this.dynamic}}`);
    assert.true(document.documentElement.classList.contains("bar"), "has .bar");

    this.set("dynamic", "baz");
    await settled();
    assert.true(document.documentElement.classList.contains("baz"), "has .baz");
    assert.false(
      document.documentElement.classList.contains("bar"),
      "does not have .bar anymore"
    );
  });
});
