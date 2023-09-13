import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render, settled } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Helper | body-class", function (hooks) {
  setupRenderingTest(hooks);

  test("A single class", async function (assert) {
    await render(hbs`{{body-class "foo"}}`);

    assert.true(document.body.classList.contains("foo"));
  });

  test("Multiple classes", async function (assert) {
    this.set("bar", "bar");
    await render(hbs`{{body-class "baz" this.bar}}`);

    assert.true(document.body.classList.contains("baz"));
    assert.true(document.body.classList.contains("bar"));
  });

  test("Empty classes", async function (assert) {
    const classesBefore = document.body.className;
    await render(hbs`{{body-class (if false "not-really")}}`);
    assert.strictEqual(document.body.className, classesBefore);
  });

  test("Dynamic classes", async function (assert) {
    this.set("dynamic", "bar");
    await render(hbs`{{body-class this.dynamic}}`);
    assert.true(document.body.classList.contains("bar"), "has .bar");

    this.set("dynamic", "baz");
    await settled();
    assert.true(document.body.classList.contains("baz"), "has .baz");
    assert.false(
      document.body.classList.contains("bar"),
      "does not have .bar anymore"
    );
  });
});
