// eslint-disable-next-line ember/no-classic-components
import Component from "@ember/component";
import { action } from "@ember/object";
import { click, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

class Foo extends Component {
  layout = hbs`<button {{on "click" (d-action "bar")}}>foobarcvx</button>`;

  @action
  bar() {
    debugger;
  }
}

module("Integration | Helper | action", function (hooks) {
  setupRenderingTest(hooks);

  test("string argument", async function (assert) {
    this.registry.register("component:foo", Foo);
    this.foo = () => assert.step("called");
    await render(hbs`<Foo />`);

    await click("button");
    assert.verifySteps(["called"]);
  });
});
