import { array } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

module("Integration | ui-kit | Helper | dConcatClass", function (hooks) {
  setupRenderingTest(hooks);

  test("One class given", async function (assert) {
    await render(<template><button class={{dConcatClass "foo"}} /></template>);

    assert.dom("button").hasAttribute("class", "foo");
  });

  test("Multiple class given", async function (assert) {
    const bar = "bar";

    await render(
      <template><button class={{dConcatClass "foo" bar}} /></template>
    );

    assert.dom("button").hasAttribute("class", "foo bar");
  });

  test("One undefined class given", async function (assert) {
    await render(
      <template><button class={{dConcatClass "foo" undefined}} /></template>
    );

    assert.dom("button").hasAttribute("class", "foo");
  });

  test("Only undefined class given", async function (assert) {
    const bar = null;

    await render(
      <template><button class={{dConcatClass null bar}} /></template>
    );

    assert.dom("button").doesNotHaveAttribute("class");
  });

  test("Helpers used", async function (assert) {
    await render(
      <template>
        <button class={{dConcatClass (if true "foo") (if true "bar")}} />
      </template>
    );

    assert.dom("button").hasAttribute("class", "foo bar");
  });

  test("Arrays", async function (assert) {
    await render(
      <template>
        <button
          class={{dConcatClass (array) (array "foo" "bar") (array null)}}
        />
      </template>
    );

    assert.dom("button").hasAttribute("class", "foo bar");
  });
});
