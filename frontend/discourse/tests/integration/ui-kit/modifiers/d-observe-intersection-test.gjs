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

    test("calls the callback with each observed entry", async function (assert) {
      const entries = [];
      const callback = (entry) => entries.push(entry);

      await render(
        <template>
          <div class="observed" {{dObserveIntersection callback}}></div>
        </template>
      );

      await this.observations[0].trigger({ isIntersecting: false });

      assert.strictEqual(entries.length, 1, "the callback runs once");
      assert.strictEqual(
        entries[0].target,
        document.querySelector(".observed"),
        "it receives the entry for the observed element"
      );
      assert.false(entries[0].isIntersecting, "the entry is passed unchanged");
    });

    test("uses a full threshold and no root margin by default", async function (assert) {
      const callback = () => {};

      await render(
        <template>
          <div class="observed" {{dObserveIntersection callback}}></div>
        </template>
      );

      assert.strictEqual(this.observations[0].options.threshold, 1);
      assert.strictEqual(
        this.observations[0].options.rootMargin,
        "0px 0px 0px 0px"
      );
    });

    test("joins an array root margin, adding px to numbers", async function (assert) {
      const callback = () => {};
      const rootMargin = [10, "5%", 0, "2px"];

      await render(
        <template>
          <div
            class="observed"
            {{dObserveIntersection callback rootMargin=rootMargin}}
          ></div>
        </template>
      );

      assert.strictEqual(
        this.observations[0].options.rootMargin,
        "10px 5% 0px 2px",
        "numbers become pixel lengths and strings are kept"
      );
    });

    test("does not observe while loading", async function (assert) {
      const callback = () => {};

      await render(
        <template>
          <div
            class="observed"
            {{dObserveIntersection callback isLoading=true}}
          ></div>
        </template>
      );

      assert.strictEqual(this.observations.length, 0, "nothing is observed");
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
