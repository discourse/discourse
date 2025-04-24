import { renderSettled } from "@ember/renderer";
import { render, waitFor } from "@ember/test-helpers";
import { setupRenderingTest } from "ember-qunit";
import { module, test } from "qunit";
import delayedDestroy from "discourse/modifiers/delayed-destroy";

module("Integration | Modifier | delayed-destroy", function (hooks) {
  setupRenderingTest(hooks);

  test("does nothing with no properties provided", async function (assert) {
    void render(
      <template>
        <div {{delayedDestroy}}></div>
      </template>
    );

    await renderSettled();
    assert.dom("div").doesNotHaveClass("is-destroying");
  });

  test("adds/removes `.is-destroying` class with animation", async function (assert) {
    let hasAnimation = true;
    const onComplete = () => (hasAnimation = false);

    void render(
      <template>
        <div
          {{delayedDestroy animate=hasAnimation onComplete=onComplete delay=10}}
        ></div>
      </template>
    );

    await renderSettled();
    assert.dom("div").hasClass("is-destroying");

    await waitFor("div:not(.is-destroying)", { timeout: 10 });

    assert.dom("div").doesNotHaveClass("is-destroying");
    assert.false(hasAnimation, "onComplete callback was executed");
  });

  test("works with elementSelector parameter", async function (assert) {
    void render(
      <template>
        <div {{delayedDestroy animate=true elementSelector=".target" delay=10}}>
          <span class="target">Target</span>
          <span class="other">Other</span>
        </div>
      </template>
    );

    await renderSettled();
    assert.dom(".target").hasClass("is-destroying");

    await waitFor(".target:not(.is-destroying)", { timeout: 10 });
    assert.dom(".target").doesNotHaveClass("is-destroying");
  });
});
