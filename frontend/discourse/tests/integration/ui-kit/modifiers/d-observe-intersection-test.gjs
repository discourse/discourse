import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import stubIntersectionObserver from "discourse/tests/helpers/stub-intersection-observer";
import dObserveIntersection from "discourse/ui-kit/modifiers/d-observe-intersection";

module(
  "Integration | ui-kit | Modifier | dObserveIntersection",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.observations = stubIntersectionObserver();
    });

    test("observes against the document when no root is given", async function (assert) {
      const callback = () => {};

      await render(
        <template>
          <div class="observed" {{dObserveIntersection callback}}></div>
        </template>
      );

      assert.strictEqual(this.observations[0].options.root, document);
    });

    test("accepts an element as the root", async function (assert) {
      const callback = () => {};
      const root = document.createElement("div");

      await render(
        <template>
          <div
            class="observed"
            {{dObserveIntersection callback root=root}}
          ></div>
        </template>
      );

      assert.strictEqual(
        this.observations[0].options.root,
        root,
        "hands the element straight to the observer"
      );
    });

    test("resolves a selector against the document", async function (assert) {
      const callback = () => {};

      await render(
        <template>
          <div class="scroll-root">
            <div
              class="observed"
              {{dObserveIntersection callback root=".scroll-root"}}
            ></div>
          </div>
        </template>
      );

      assert.strictEqual(
        this.observations[0].options.root,
        document.querySelector(".scroll-root"),
        "an already-mounted root resolves by the time the modifier installs"
      );
    });

    test("falls back to the document for an empty selector", async function (assert) {
      const callback = () => {};

      await render(
        <template>
          <div class="observed" {{dObserveIntersection callback root=""}}></div>
        </template>
      );

      assert.strictEqual(
        this.observations[0].options.root,
        document,
        "an empty selector is not passed to querySelector, which rejects it"
      );
    });

    test("an unmatched selector leaves the observer rooted at the viewport", async function (assert) {
      const callback = () => {};

      await render(
        <template>
          <div
            class="observed"
            {{dObserveIntersection callback root=".not-mounted"}}
          ></div>
        </template>
      );

      assert.strictEqual(
        this.observations[0].options.root,
        null,
        "a root that cannot be resolved degrades silently rather than throwing"
      );
    });
  }
);
