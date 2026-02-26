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
});
