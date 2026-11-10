import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dNumber from "discourse/ui-kit/helpers/d-number";

module("Integration | ui-kit | Helper | dNumber", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a rounded number", async function (assert) {
    await render(<template>{{dNumber "41.6"}}</template>);

    assert.dom("span.number").hasText("42");
    assert.dom("span.number").doesNotHaveAttribute("title");
  });

  test("renders zero for something that isn't a number", async function (assert) {
    await render(<template>{{dNumber "many"}}</template>);

    assert.dom("span.number").hasText("0");
  });

  test("shortens large numbers and puts the full number in the title", async function (assert) {
    await render(<template>{{dNumber 1500}}</template>);

    assert.dom("span.number").hasText("1.5k");
    assert.dom("span.number").hasAttribute("title", "1,500");
  });

  test("drops the title with noTitle", async function (assert) {
    await render(<template>{{dNumber 1500 noTitle=true}}</template>);

    assert.dom("span.number").doesNotHaveAttribute("title");
  });

  test("passes maxDisplay to the formatter", async function (assert) {
    await render(<template>{{dNumber 1500 maxDisplay=500}}</template>);

    assert.dom("span.number").hasText("500+");
  });

  test("adds the class", async function (assert) {
    await render(<template>{{dNumber 3 class="gizmo"}}</template>);

    assert.dom("span.number.gizmo").exists();
  });

  test("translates the title with numberKey", async function (assert) {
    await render(<template>{{dNumber 1500 numberKey="views_long"}}</template>);

    assert
      .dom("span.number")
      .hasAttribute("title", /^this topic has been viewed 1,?500 times$/);
  });

  test("adds an escaped aria label", async function (assert) {
    await render(<template>{{dNumber 3 ariaLabel="Gizmo's count"}}</template>);

    assert.dom("span.number").hasAttribute("aria-label", "Gizmo's count");
  });
});
