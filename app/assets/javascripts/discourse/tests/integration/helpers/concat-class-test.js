import { assert, module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { query } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Helper | concat-class", function (hooks) {
  setupRenderingTest(hooks);

  test("One class given", async function () {
    await render(hbs`<button class={{concat-class "foo"}} />`);

    assert.equal(query("button").className, "foo");
  });

  test("Multiple class given", async function () {
    this.set("bar", "bar");
    await render(hbs`<button class={{concat-class "foo" this.bar}} />`);

    assert.equal(query("button").className, "foo bar");
  });

  test("One undefined class given", async function () {
    this.set("bar", null);
    await render(hbs`<button class={{concat-class "foo" this.bar}} />`);

    assert.equal(query("button").className, "foo");
  });

  test("Only undefined class given", async function () {
    this.set("bar", null);
    await render(hbs`<button class={{concat-class null this.bar}} />`);

    assert.notOk(query("button").hasAttribute("class"));
  });

  test("Helpers used", async function () {
    await render(
      hbs`<button class={{concat-class (if true "foo") (if true "bar")}} />`
    );

    assert.equal(query("button").className, "foo bar");
  });
});
