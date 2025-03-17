import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { setupRenderingTest } from "ember-qunit";
import { module, test } from "qunit";

module("Integration | Modifier | delayed-destroy", function (hooks) {
  setupRenderingTest(hooks);

  test("does nothing when animate is false", async function (assert) {
    await render(hbs`<div {{delayed-destroy}}></div>`);
    assert.dom("div").doesNotHaveClass("is-closing");
  });

  test("adds/removes `.is-closing` class with animation", async function (assert) {
    this.set("hasAnimation", true);
    this.set("onComplete", () => (this.hasAnimation = false));

    await render(
      hbs`<div {{delayed-destroy animate=this.hasAnimation onComplete=this.onComplete}}></div>`
    );
    // TODO: couldn't figure out how I can test `.is-closing` presence,
    // before it's removed after timeout:
    // assert.dom("div").hasClass("is-closing");

    // await waitFor("div:not(.is-closing)", { timeout: 11 });

    assert.dom("div").doesNotHaveClass("is-closing");
    assert.false(this.hasAnimation, "onComplete callback was executed");
  });

  test("works with element selector", async function (assert) {
    await render(
      hbs`<div {{delayed-destroy animate=true elementSelector=".target"}}>
        <span class="target">Target</span>
        <span class="other">Other</span>
      </div>`
    );

    // TODO: couldn't figure out how I can test `.is-closing` presence,
    // before it's removed after timeout:
    // await waitUntil(function () {
    //   return assert.dom(".target").hasClass("is-closing");
    // });
    assert.dom(".other").doesNotHaveClass("is-closing");

    // await waitFor(".target:not(.is-closing)", { timeout: 100 });
    assert.dom(".target").doesNotHaveClass("is-closing");
  });
});
