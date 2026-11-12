import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dScrollIntoView from "discourse/ui-kit/modifiers/d-scroll-into-view";

module("Integration | ui-kit | Modifier | dScrollIntoView", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.scrollStub = sinon.stub(Element.prototype, "scrollIntoView");
  });

  test("scrolls smoothly to the nearest edge by default", async function (assert) {
    await render(
      <template>
        <div class="target" {{dScrollIntoView true}}></div>
      </template>
    );

    assert.true(this.scrollStub.calledOnce, "one scroll is requested");
    assert.true(
      this.scrollStub.calledOn(document.querySelector(".target")),
      "the element is scrolled into view"
    );
    assert.deepEqual(
      this.scrollStub.firstCall.args,
      [{ behavior: "smooth", block: "nearest" }],
      "the default options are used"
    );
  });

  test("merges the given options over the defaults", async function (assert) {
    await render(
      <template>
        <div
          class="target"
          {{dScrollIntoView true (hash block="center")}}
        ></div>
      </template>
    );

    assert.deepEqual(
      this.scrollStub.firstCall.args,
      [{ behavior: "smooth", block: "center" }],
      "the given option replaces its default and the rest are kept"
    );
  });

  test("does not scroll while the condition is false", async function (assert) {
    await render(
      <template>
        <div class="target" {{dScrollIntoView false}}></div>
      </template>
    );

    assert.true(this.scrollStub.notCalled, "the element is not scrolled");
  });

  test("scrolls when the condition becomes true", async function (assert) {
    const shouldScroll = tracked(false);

    await render(
      <template>
        <div class="target" {{dScrollIntoView shouldScroll.value}}></div>
      </template>
    );

    shouldScroll.value = true;
    await settled();

    assert.true(
      this.scrollStub.calledOnce,
      "the element is scrolled after the update"
    );
  });
});
