// eslint-disable-next-line ember/no-classic-components
import Component from "@ember/component";
import { action } from "@ember/object";
import { click, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { withSilencedDeprecationsAsync } from "discourse/lib/deprecated";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

class FooString extends Component {
  layout = hbs`<button {{on "click" (action "bar" 123)}}>test</button>`;

  @action
  bar(value) {
    this.callback(value);
  }
}

class FooReference extends Component {
  layout = hbs`<button {{on "click" (action this.bar)}}>test</button>`;

  @action
  bar() {
    this.callback();
  }
}

// This is a core test but has to be in a theme since the transform
// (that injects `this` into actions' params) is applied only to
// themes and plugins
module("Integration | Helper | action", function (hooks) {
  setupRenderingTest(hooks);

  test("string argument", async function (assert) {
    this.registry.register("component:foo", FooString);
    this.callback = (value) => {
      assert.step("called");
      assert.strictEqual(value, 123);
    };

    await withSilencedDeprecationsAsync(
      "discourse.template-action",
      async () => {
        await render(hbs`<Foo @callback={{this.callback}} />`);
      }
    );

    await click("button");
    assert.verifySteps(["called"]);
  });

  test("reference argument", async function (assert) {
    this.registry.register("component:foo", FooReference);
    this.callback = () => assert.step("called");

    await withSilencedDeprecationsAsync(
      "discourse.template-action",
      async () => {
        await render(hbs`<Foo @callback={{this.callback}} />`);
      }
    );

    await click("button");
    assert.verifySteps(["called"]);
  });
});
