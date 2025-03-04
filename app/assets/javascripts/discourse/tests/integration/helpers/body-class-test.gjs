import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import bodyClass from "discourse/helpers/body-class";

module("Integration | Helper | body-class", function (hooks) {
  setupRenderingTest(hooks);

  test("A single class", async function (assert) {
    await render(<template>{{bodyClass "foo"}}</template>);

    assert.dom(document.body).hasClass("foo");
  });

  test("Multiple classes", async function (assert) {const self = this;

    this.set("bar", "bar");
    await render(<template>{{bodyClass "baz" self.bar}}</template>);

    assert.dom(document.body).hasClass("baz");
    assert.dom(document.body).hasClass("bar");
  });

  test("Empty classes", async function (assert) {
    const classesBefore = document.body.className;
    await render(<template>{{bodyClass (if false "not-really")}}</template>);
    assert.strictEqual(document.body.className, classesBefore);
  });

  test("Dynamic classes", async function (assert) {const self = this;

    this.set("dynamic", "bar");
    await render(<template>{{bodyClass self.dynamic}}</template>);
    assert.dom(document.body).hasClass("bar");

    this.set("dynamic", "baz");
    await settled();
    assert.dom(document.body).hasClass("baz");
    assert
      .dom(document.body)
      .doesNotHaveClass("bar", "does not have .bar anymore");
  });
});
