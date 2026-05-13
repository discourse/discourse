import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";

module("Unit | Utility | keyboard-shortcuts", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    sinon.stub(DiscourseURL, "routeTo");
  });

  test("goBack calls history.back", function (assert) {
    let called = false;
    sinon.stub(history, "back").callsFake(function () {
      called = true;
    });

    const keyboardShortcuts = this.owner.lookup("service:keyboard-shortcuts");
    keyboardShortcuts.goBack();
    assert.true(called, "history.back is called");
  });

  test("nextSection calls _changeSection with 1", function (assert) {
    const keyboardShortcuts = this.owner.lookup("service:keyboard-shortcuts");
    let spy = sinon.spy(keyboardShortcuts, "_changeSection");

    keyboardShortcuts.nextSection();
    assert.true(spy.calledWith(1), "_changeSection is called with 1");
  });

  test("prevSection calls _changeSection with -1", function (assert) {
    const keyboardShortcuts = this.owner.lookup("service:keyboard-shortcuts");
    let spy = sinon.spy(keyboardShortcuts, "_changeSection");

    keyboardShortcuts.prevSection();
    assert.true(spy.calledWith(-1), "_changeSection is called with -1");
  });

  module("addShortcut context option", function () {
    test("fires new handler when CSS selector context matches", function (assert) {
      const ks = this.owner.lookup("service:keyboard-shortcuts");
      let handlerACalled = false;
      let handlerBCalled = false;

      ks.addShortcut("x", () => (handlerACalled = true), { anonymous: true });

      const el = document.createElement("div");
      el.classList.add("test-context-target");
      document.body.appendChild(el);

      try {
        ks.addShortcut("x", () => (handlerBCalled = true), {
          anonymous: true,
          context: ".test-context-target",
        });

        // Simulate keypress via ItsATrap
        ks.keyTrapper.trigger("x");

        assert.true(handlerBCalled, "new handler fires when context matches");
        assert.false(handlerACalled, "previous handler does not fire");
      } finally {
        el.remove();
      }
    });

    test("falls back to previous handler when context does not match", function (assert) {
      const ks = this.owner.lookup("service:keyboard-shortcuts");
      let handlerACalled = false;
      let handlerBCalled = false;

      ks.addShortcut("y", () => (handlerACalled = true), { anonymous: true });
      ks.addShortcut("y", () => (handlerBCalled = true), {
        anonymous: true,
        context: ".nonexistent-element",
      });

      ks.keyTrapper.trigger("y");

      assert.true(handlerACalled, "previous handler fires as fallback");
      assert.false(handlerBCalled, "new handler does not fire");
    });

    test("no error when no previous binding exists and context does not match", function (assert) {
      const ks = this.owner.lookup("service:keyboard-shortcuts");
      let called = false;

      ks.addShortcut("q w", () => (called = true), {
        anonymous: true,
        context: ".nonexistent-element",
      });

      ks.keyTrapper.trigger("q w");

      assert.false(called, "handler does not fire");
    });

    test("function context is evaluated", function (assert) {
      const ks = this.owner.lookup("service:keyboard-shortcuts");
      let contextActive = false;
      let handlerACalled = false;
      let handlerBCalled = false;

      ks.addShortcut("z", () => (handlerACalled = true), { anonymous: true });
      ks.addShortcut("z", () => (handlerBCalled = true), {
        anonymous: true,
        context: () => contextActive,
      });

      ks.keyTrapper.trigger("z");
      assert.true(handlerACalled, "fallback fires when function returns false");
      assert.false(handlerBCalled);

      handlerACalled = false;
      contextActive = true;
      ks.keyTrapper.trigger("z");
      assert.true(
        handlerBCalled,
        "new handler fires when function returns true"
      );
      assert.false(handlerACalled);
    });

    test("chained context bindings fall back correctly", function (assert) {
      const ks = this.owner.lookup("service:keyboard-shortcuts");
      const calls = [];

      ks.addShortcut("w", () => calls.push("original"), { anonymous: true });
      ks.addShortcut("w", () => calls.push("plugin-a"), {
        anonymous: true,
        context: ".plugin-a-active",
      });
      ks.addShortcut("w", () => calls.push("plugin-b"), {
        anonymous: true,
        context: ".plugin-b-active",
      });

      // Neither context matches — should fall through to original
      ks.keyTrapper.trigger("w");
      assert.deepEqual(calls, ["original"]);

      calls.length = 0;
      const elA = document.createElement("div");
      elA.classList.add("plugin-a-active");
      document.body.appendChild(elA);

      try {
        // plugin-b context doesn't match, falls to plugin-a which matches
        ks.keyTrapper.trigger("w");
        assert.deepEqual(calls, ["plugin-a"]);
      } finally {
        elA.remove();
      }

      calls.length = 0;
      const elB = document.createElement("div");
      elB.classList.add("plugin-b-active");
      document.body.appendChild(elB);

      try {
        // plugin-b context matches
        ks.keyTrapper.trigger("w");
        assert.deepEqual(calls, ["plugin-b"]);
      } finally {
        elB.remove();
      }
    });
  });

  module("nested view navigation", function (nestedHooks) {
    // Builds a minimal nested-view DOM with three root posts. Each root has
    // an inner subtree the navigation should ignore.
    function buildNestedView() {
      const view = document.createElement("div");
      view.className = "nested-view";

      const roots = document.createElement("div");
      roots.className = "nested-view__roots";
      view.appendChild(roots);

      ["r1", "r2", "r3"].forEach((id) => {
        const root = document.createElement("div");
        root.className = "nested-post";
        root.id = id;
        // A descendant .nested-post that root-only navigation must NOT pick up.
        const child = document.createElement("div");
        child.className = "nested-post";
        child.id = `${id}-child`;
        root.appendChild(child);
        roots.appendChild(root);
      });

      document.body.appendChild(view);
      return view;
    }

    nestedHooks.afterEach(function () {
      document
        .querySelectorAll(".nested-view, .topic-post.selected")
        .forEach((el) => el.remove());
    });

    test("selectDown seeds the first root when nothing is selected", function (assert) {
      buildNestedView();
      const ks = this.owner.lookup("service:keyboard-shortcuts");

      ks.selectDown();

      assert.strictEqual(
        document.querySelector("[data-keyboard-selected]")?.id,
        "r1"
      );
    });

    test("selectDown / selectUp walk root replies only, ignoring deeper posts", function (assert) {
      buildNestedView();
      const ks = this.owner.lookup("service:keyboard-shortcuts");

      ks.selectDown(); // r1
      ks.selectDown(); // r2
      assert.strictEqual(
        document.querySelector("[data-keyboard-selected]")?.id,
        "r2",
        "skips r1's descendant and lands on the next root"
      );

      ks.selectDown(); // r3
      ks.selectDown(); // no-op past the last root
      assert.strictEqual(
        document.querySelector("[data-keyboard-selected]")?.id,
        "r3",
        "no wrap-around past last root"
      );

      ks.selectUp(); // r2
      ks.selectUp(); // r1
      assert.strictEqual(
        document.querySelector("[data-keyboard-selected]")?.id,
        "r1"
      );

      ks.selectUp(); // no-op before the first root
      assert.strictEqual(
        document.querySelector("[data-keyboard-selected]")?.id,
        "r1",
        "no wrap-around past first root"
      );
    });

    test("selectDown outside the nested view delegates to _moveSelection", function (assert) {
      const ks = this.owner.lookup("service:keyboard-shortcuts");
      const stub = sinon.stub(ks, "_moveSelection");
      try {
        ks.selectDown();
        assert.true(
          stub.calledWith({ direction: 1, scrollWithinPosts: true }),
          "falls through to flat-stream selection when .nested-view is absent"
        );
      } finally {
        stub.restore();
      }
    });
  });
});
