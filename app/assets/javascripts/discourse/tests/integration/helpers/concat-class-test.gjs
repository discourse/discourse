import { array } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import concatClass from "discourse/helpers/concat-class";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Helper | concat-class", function (hooks) {
  setupRenderingTest(hooks);

  test("One class given", async function (assert) {
    await render(<template><button class={{concatClass "foo"}} /></template>);

    assert.dom("button").hasAttribute("class", "foo");
  });

  test("Multiple class given", async function (assert) {
    const bar = "bar";

    await render(
      <template><button class={{concatClass "foo" bar}} /></template>
    );

    assert.dom("button").hasAttribute("class", "foo bar");
  });

  test("One undefined class given", async function (assert) {
    await render(
      <template><button class={{concatClass "foo" undefined}} /></template>
    );

    assert.dom("button").hasAttribute("class", "foo");
  });

  test("Only undefined class given", async function (assert) {
    const bar = null;

    await render(
      <template><button class={{concatClass null bar}} /></template>
    );

    assert.dom("button").doesNotHaveAttribute("class");
  });

  test("Helpers used", async function (assert) {
    await render(
      <template>
        <button class={{concatClass (if true "foo") (if true "bar")}} />
      </template>
    );

    assert.dom("button").hasAttribute("class", "foo bar");
  });

  test("Arrays", async function (assert) {
    await render(
      <template>
        <button
          class={{concatClass (array) (array "foo" "bar") (array null)}}
        />
      </template>
    );

    assert.dom("button").hasAttribute("class", "foo bar");
  });
});
