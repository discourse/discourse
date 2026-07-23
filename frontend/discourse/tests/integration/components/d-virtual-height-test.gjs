import { getOwner } from "@ember/owner";
import { click, render, settled, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import DVirtualHeight from "discourse/components/d-virtual-height";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | DVirtualHeight", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    forceMobile();
  });

  hooks.afterEach(function () {
    document.documentElement.classList.remove("keyboard-visible");
    document.documentElement.style.removeProperty("--composer-vh");
  });

  test("keyboard:will-hide tears down the keyboard state immediately", async function (assert) {
    await render(<template><DVirtualHeight /></template>);

    const docEl = document.documentElement;
    docEl.classList.add("keyboard-visible");

    const appEvents = getOwner(this).lookup("service:app-events");
    const received = [];
    const recorder = (visible) => received.push(visible);
    appEvents.on("keyboard-visibility-change", recorder);

    try {
      appEvents.trigger("keyboard:will-hide");

      assert.dom(docEl).doesNotHaveClass("keyboard-visible");
      assert.deepEqual(received, [false]);
      assert.strictEqual(
        docEl.style.getPropertyValue("--composer-vh"),
        `${Math.round(window.innerHeight) / 100}px`,
        "composer height is grown to the keyboard-free viewport"
      );
    } finally {
      appEvents.off("keyboard-visibility-change", recorder);
    }
  });

  test("focus settling outside editable elements tears down the keyboard state", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <button type="button">other</button>
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = document.querySelector("#ember-testing textarea");

    editableEl.focus();
    docEl.classList.add("keyboard-visible");

    editableEl.blur();
    await settled();

    assert.dom(docEl).doesNotHaveClass("keyboard-visible");
  });

  test("focus lost to a tap on inert content tears down without settling", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <div class="inert-content">plain text</div>
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = document.querySelector("#ember-testing textarea");

    editableEl.focus();
    docEl.classList.add("keyboard-visible");

    await triggerEvent("#ember-testing .inert-content", "touchstart");
    editableEl.blur();

    // asserted before any timers can run
    assert.dom(docEl).doesNotHaveClass("keyboard-visible");
  });

  test("focus moving to another editable element keeps the keyboard state", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <input type="text" />
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = document.querySelector("#ember-testing textarea");
    const inputEl = document.querySelector("#ember-testing input");

    editableEl.focus();
    docEl.classList.add("keyboard-visible");

    inputEl.focus();
    await settled();

    assert.dom(docEl).hasClass("keyboard-visible");
  });

  test("the dismissing tap's ghost click does not activate controls", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <div class="inert-content">plain text</div>
        <button type="button" class="target">target</button>
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = document.querySelector("#ember-testing textarea");
    const target = document.querySelector("#ember-testing .target");

    let activations = 0;
    target.addEventListener("click", () => activations++);

    editableEl.focus();
    docEl.classList.add("keyboard-visible");

    await triggerEvent("#ember-testing .inert-content", "touchstart");
    editableEl.blur();
    assert.dom(docEl).doesNotHaveClass("keyboard-visible");

    await click("#ember-testing .target");
    assert.strictEqual(activations, 0, "the tap's own click is swallowed");

    await click("#ember-testing .target");
    assert.strictEqual(activations, 1, "a deliberate follow-up tap works");
  });

  test("a dismissing drag does not swallow the next click", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <div class="inert-content">plain text</div>
        <button type="button" class="target">target</button>
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = document.querySelector("#ember-testing textarea");
    const target = document.querySelector("#ember-testing .target");

    let activations = 0;
    target.addEventListener("click", () => activations++);

    editableEl.focus();
    docEl.classList.add("keyboard-visible");

    await triggerEvent("#ember-testing .inert-content", "touchstart", {
      touches: [{ clientX: 0, clientY: 0 }],
    });
    await triggerEvent("#ember-testing .inert-content", "touchend", {
      changedTouches: [{ clientX: 0, clientY: 120 }],
    });
    editableEl.blur();
    assert.dom(docEl).doesNotHaveClass("keyboard-visible");

    await click("#ember-testing .target");
    assert.strictEqual(activations, 1, "drags synthesize no click to swallow");
  });

  test("refocusing an editable right after a dismiss restores the keyboard state", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <div class="inert-content">plain text</div>
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = document.querySelector("#ember-testing textarea");

    editableEl.focus();
    docEl.classList.add("keyboard-visible");
    docEl.style.setProperty("--composer-vh", "5px");

    await triggerEvent("#ember-testing .inert-content", "touchstart");
    editableEl.blur();
    assert.dom(docEl).doesNotHaveClass("keyboard-visible");

    const appEvents = getOwner(this).lookup("service:app-events");
    const received = [];
    const recorder = (visible) => received.push(visible);
    appEvents.on("keyboard-visibility-change", recorder);

    try {
      editableEl.focus();

      assert.dom(docEl).hasClass("keyboard-visible");
      assert.strictEqual(
        docEl.style.getPropertyValue("--composer-vh"),
        "5px",
        "the keyboard-sized composer height is restored"
      );
      assert.deepEqual(received, [true]);
    } finally {
      appEvents.off("keyboard-visibility-change", recorder);
    }
  });

  test("focusing an editable applies the last known keyboard height until the viewport reports", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <input type="text" />
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = document.querySelector("#ember-testing textarea");
    const inputEl = document.querySelector("#ember-testing input");

    editableEl.focus();
    docEl.classList.add("keyboard-visible");

    const appEvents = getOwner(this).lookup("service:app-events");
    appEvents.trigger("keyboard:will-hide");
    assert.dom(docEl).doesNotHaveClass("keyboard-visible");

    // the viewport reporting settles the provisional hide
    window.visualViewport.dispatchEvent(new Event("resize"));
    await settled();

    const received = [];
    const recorder = (visible) => received.push(visible);
    appEvents.on("keyboard-visibility-change", recorder);

    try {
      inputEl.focus();

      assert.dom(docEl).hasClass("keyboard-visible");
      assert.deepEqual(received, [true]);

      // no real keyboard ever reported: the optimistic state reverts
      await settled();
      assert.dom(docEl).doesNotHaveClass("keyboard-visible");
      assert.deepEqual(received, [true, false]);

      // and prediction stays disabled until a real keyboard is seen
      editableEl.focus();
      assert.dom(docEl).doesNotHaveClass("keyboard-visible");
    } finally {
      appEvents.off("keyboard-visibility-change", recorder);
    }
  });

  test("an unconfirmed prediction stays provisional through a dismiss and refocus", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <input type="text" />
        <div class="inert-content">plain text</div>
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = document.querySelector("#ember-testing textarea");
    const inputEl = document.querySelector("#ember-testing input");

    editableEl.focus();
    docEl.classList.add("keyboard-visible");

    const appEvents = getOwner(this).lookup("service:app-events");
    appEvents.trigger("keyboard:will-hide");
    window.visualViewport.dispatchEvent(new Event("resize"));
    await settled();

    // predictive show (unconfirmed), dismissed by an inert tap; dispatched
    // synchronously so no await runs the pending revert timer early
    inputEl.focus();
    assert.dom(docEl).hasClass("keyboard-visible", "predictive show applies");
    document
      .querySelector("#ember-testing .inert-content")
      .dispatchEvent(new TouchEvent("touchstart", { bubbles: true }));
    inputEl.blur();
    assert.dom(docEl).doesNotHaveClass("keyboard-visible");

    // the restored snapshot descends from an unconfirmed prediction, so it
    // must revert too instead of persisting as phantom state
    editableEl.focus();
    assert.dom(docEl).hasClass("keyboard-visible", "snapshot restores");

    await settled();
    assert.dom(docEl).doesNotHaveClass("keyboard-visible");
  });

  test("focusing a select does not predict a keyboard", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <select><option>a</option></select>
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = document.querySelector("#ember-testing textarea");
    const selectEl = document.querySelector("#ember-testing select");

    editableEl.focus();
    docEl.classList.add("keyboard-visible");

    const appEvents = getOwner(this).lookup("service:app-events");
    appEvents.trigger("keyboard:will-hide");
    window.visualViewport.dispatchEvent(new Event("resize"));
    await settled();

    selectEl.focus();
    assert.dom(docEl).doesNotHaveClass("keyboard-visible");
  });

  test("window blur tears down the keyboard state immediately", async function (assert) {
    await render(<template><DVirtualHeight /></template>);

    const docEl = document.documentElement;
    docEl.classList.add("keyboard-visible");

    window.dispatchEvent(new Event("blur"));

    assert.dom(docEl).doesNotHaveClass("keyboard-visible");
  });

  test("keyboard:will-hide is a no-op while the keyboard is not visible", async function (assert) {
    await render(<template><DVirtualHeight /></template>);

    const appEvents = getOwner(this).lookup("service:app-events");
    const received = [];
    const recorder = (visible) => received.push(visible);
    appEvents.on("keyboard-visibility-change", recorder);

    try {
      appEvents.trigger("keyboard:will-hide");

      assert.deepEqual(received, []);
    } finally {
      appEvents.off("keyboard-visibility-change", recorder);
    }
  });
});
