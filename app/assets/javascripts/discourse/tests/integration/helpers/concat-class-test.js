import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Helper | concat-class", function (hooks) {
  setupRenderingTest(hooks);

  test("One class given", async function (assert) {
    await render(hbs`<button class={{concat-class "foo"}} />`);

    assert.dom("button").hasAttribute("class", "foo");
  });

  test("Multiple class given", async function (assert) {
    this.set("bar", "bar");
    await render(hbs`<button class={{concat-class "foo" this.bar}} />`);

    assert.dom("button").hasAttribute("class", "foo bar");
  });

  test("One undefined class given", async function (assert) {
    this.set("bar", null);
    await render(hbs`<button class={{concat-class "foo" this.bar}} />`);

    assert.dom("button").hasAttribute("class", "foo");
  });

  test("Only undefined class given", async function (assert) {
    this.set("bar", null);
    await render(hbs`<button class={{concat-class null this.bar}} />`);

    assert.dom("button").doesNotHaveAttribute("class");
  });

  test("Helpers used", async function (assert) {
    await render(
      hbs`<button class={{concat-class (if true "foo") (if true "bar")}} />`
    );

    assert.dom("button").hasAttribute("class", "foo bar");
  });

  test("Arrays", async function (assert) {
    await render(
      hbs`<button class={{concat-class (array) (array "foo" "bar") (array null)}} />`
    );

    assert.dom("button").hasAttribute("class", "foo bar");
  });
});
