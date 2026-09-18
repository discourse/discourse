import { getOwner } from "@ember/owner";
import { click, find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import DVirtualHeight from "discourse/components/d-virtual-height";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const docEl = document.documentElement;

// touch dispatch is synchronous so wall-clock gaps between events can't
// exceed the recent-touch window under a slow test runner
function touch(el, type, props = {}) {
  const event = new Event(type, { bubbles: true });
  Object.assign(event, props);
  el.dispatchEvent(event);
}

// a keyboard of `px` height in the viewport geometry; 0 removes it
function setViewportKeyboard(px) {
  if (px) {
    Object.defineProperty(window.visualViewport, "height", {
      configurable: true,
      value: window.innerHeight - px,
    });
  } else {
    delete window.visualViewport.height;
  }
}

async function reportViewport() {
  window.visualViewport.dispatchEvent(new Event("resize"));
  await settled();
}

module("Integration | Component | DVirtualHeight", function (hooks) {
  setupRenderingTest(hooks);

  let appEvents;
  let editable;
  let teardown;

  hooks.beforeEach(async function () {
    forceMobile();
    appEvents = getOwner(this).lookup("service:app-events");
    teardown = [];

    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <input type="text" class="field" />
        <textarea class="readonly" readonly></textarea>
        <select><option>a</option></select>
        <input type="checkbox" />
        <div class="inert-content" role="none">plain text</div>
        <button type="button" class="target">target</button>
      </template>
    );

    editable = find("textarea");
  });

  hooks.afterEach(function () {
    teardown.forEach((cleanup) => cleanup());
    docEl.classList.remove("keyboard-visible");
    docEl.style.removeProperty("--composer-vh");
    setViewportKeyboard(0);
  });

  function recordVisibility() {
    const received = [];
    const recorder = (visible) => received.push(visible);
    appEvents.on("keyboard-visibility-change", recorder);
    teardown.push(() => appEvents.off("keyboard-visibility-change", recorder));
    return received;
  }

  function countClicks(selector) {
    const counter = { count: 0 };
    find(selector).addEventListener("click", () => counter.count++);
    return counter;
  }

  function focusWithKeyboard() {
    editable.focus();
    docEl.classList.add("keyboard-visible");
  }

  function dismissByInertTap() {
    touch(find(".inert-content"), "touchstart");
    editable.blur();
  }

  // record a keyboard height, then settle its dismissal, leaving a snapshot
  // for prediction to restore
  async function learnKeyboardHeight() {
    focusWithKeyboard();
    appEvents.trigger("keyboard:will-hide");
    await reportViewport();
  }

  test("keyboard:will-hide tears down the keyboard state immediately", function (assert) {
    docEl.classList.add("keyboard-visible");
    const received = recordVisibility();

    appEvents.trigger("keyboard:will-hide");

    assert.dom(docEl).doesNotHaveClass("keyboard-visible");
    assert.deepEqual(received, [false]);
    assert.strictEqual(
      docEl.style.getPropertyValue("--composer-vh"),
      `${Math.round(window.innerHeight) / 100}px`,
      "composer height is grown to the keyboard-free viewport"
    );
  });

  test("keyboard:will-hide is a no-op while the keyboard is not visible", function (assert) {
    const received = recordVisibility();

    appEvents.trigger("keyboard:will-hide");

    assert.deepEqual(received, []);
  });

  test("focus settling outside editable elements tears down the keyboard state", async function (assert) {
    focusWithKeyboard();

    editable.blur();
    await settled();

    assert.dom(docEl).doesNotHaveClass("keyboard-visible");
  });

  test("focus moving to another editable element keeps the keyboard state", async function (assert) {
    focusWithKeyboard();

    find(".field").focus();
    await settled();

    assert.dom(docEl).hasClass("keyboard-visible");
  });

  test("focus lost to a tap on inert content tears down without settling", function (assert) {
    focusWithKeyboard();

    dismissByInertTap();

    assert
      .dom(docEl)
      .doesNotHaveClass("keyboard-visible", "torn down before any timers run");
  });

  test("the dismissing tap's ghost click does not activate controls", async function (assert) {
    const clicks = countClicks(".target");
    focusWithKeyboard();

    dismissByInertTap();

    await click("#ember-testing .target");
    assert.strictEqual(clicks.count, 0, "the tap's own click is swallowed");

    await click("#ember-testing .target");
    assert.strictEqual(clicks.count, 1, "a deliberate follow-up tap works");
  });

  test("the dismissing tap's click passes through when it lands on the touched element", async function (assert) {
    const clicks = countClicks(".inert-content");
    focusWithKeyboard();

    // the reflow did not move this element out from under the finger, so its
    // own click must still activate it
    dismissByInertTap();

    await click("#ember-testing .inert-content");
    assert.strictEqual(clicks.count, 1, "the touched element's click lands");
  });

  test("a dismissing drag does not swallow the next click", async function (assert) {
    const clicks = countClicks(".target");
    focusWithKeyboard();

    touch(find(".inert-content"), "touchstart", {
      touches: [{ clientX: 0, clientY: 0 }],
    });
    touch(find(".inert-content"), "touchend", {
      changedTouches: [{ clientX: 0, clientY: 120 }],
    });
    editable.blur();
    assert.dom(docEl).doesNotHaveClass("keyboard-visible");

    await click("#ember-testing .target");
    assert.strictEqual(clicks.count, 1, "drags synthesize no click to swallow");
  });

  test("a cancelled touch does not arm the ghost click suppression", async function (assert) {
    const clicks = countClicks(".target");
    focusWithKeyboard();

    touch(find(".inert-content"), "touchstart");
    touch(find(".inert-content"), "touchcancel");
    editable.blur();
    assert.dom(docEl).doesNotHaveClass("keyboard-visible");

    await click("#ember-testing .target");
    assert.strictEqual(clicks.count, 1, "no ghost click is expected");
  });

  test("a new touch releases the ghost click suppression", async function (assert) {
    const clicks = countClicks(".target");
    focusWithKeyboard();

    dismissByInertTap();

    // a deliberate follow-up tap within the ghost window
    touch(find(".target"), "touchstart");
    await click("#ember-testing .target");
    assert.strictEqual(clicks.count, 1, "the new tap's click lands");
  });

  test("tapping back into an editable right after a dismiss restores the keyboard state", async function (assert) {
    // a real keyboard shrinks the viewport, setting the keyboard-sized height
    editable.focus();
    setViewportKeyboard(300);
    await reportViewport();
    const keyboardVh = docEl.style.getPropertyValue("--composer-vh");
    assert.dom(docEl).hasClass("keyboard-visible");

    dismissByInertTap();
    assert.dom(docEl).doesNotHaveClass("keyboard-visible");

    const received = recordVisibility();
    touch(editable, "touchstart");
    editable.focus();

    assert.dom(docEl).hasClass("keyboard-visible");
    assert.strictEqual(
      docEl.style.getPropertyValue("--composer-vh"),
      keyboardVh,
      "the keyboard-sized composer height is restored"
    );
    assert.deepEqual(received, [true]);
  });

  test("a restored keyboard state reverts when the keyboard stays hidden", async function (assert) {
    editable.focus();
    setViewportKeyboard(300);
    await reportViewport();
    assert.dom(docEl).hasClass("keyboard-visible", "keyboard is confirmed");

    // the keyboard leaves the geometry, dismissed by an inert tap
    setViewportKeyboard(0);
    dismissByInertTap();

    touch(editable, "touchstart");
    editable.focus();
    assert.dom(docEl).hasClass("keyboard-visible", "snapshot restores");

    await settled();
    assert
      .dom(docEl)
      .doesNotHaveClass(
        "keyboard-visible",
        "a restore the viewport geometry contradicts reverts"
      );
  });

  test("a restored keyboard state is kept while the viewport still reports one", async function (assert) {
    editable.focus();
    setViewportKeyboard(300);
    await reportViewport();
    assert.dom(docEl).hasClass("keyboard-visible", "keyboard is confirmed");

    // dismissed and refocused mid-hide: the keyboard never actually left
    dismissByInertTap();

    touch(editable, "touchstart");
    editable.focus();
    assert.dom(docEl).hasClass("keyboard-visible", "snapshot restores");

    await settled();
    assert
      .dom(docEl)
      .hasClass("keyboard-visible", "the geometry-backed restore holds");
  });

  test("focusing an editable applies the last known keyboard height until the viewport reports", async function (assert) {
    await learnKeyboardHeight();
    const received = recordVisibility();

    // a gesture-driven focus (a tap raises the keyboard)
    touch(find(".field"), "touchstart");
    find(".field").focus();

    assert.dom(docEl).hasClass("keyboard-visible");
    assert.deepEqual(received, [true]);

    await settled();
    assert
      .dom(docEl)
      .doesNotHaveClass(
        "keyboard-visible",
        "no real keyboard ever reported: the optimistic state reverts"
      );
    assert.deepEqual(received, [true, false]);

    touch(editable, "touchstart");
    editable.focus();
    assert
      .dom(docEl)
      .doesNotHaveClass(
        "keyboard-visible",
        "prediction stays disabled until a real keyboard is seen"
      );
  });

  test("tapping a control that focuses another field does not predict", async function (assert) {
    await learnKeyboardHeight();

    // e.g. a chooser: the tap lands on its trigger while focus lands
    // programmatically on its filter input, which raises no keyboard
    touch(find(".target"), "touchstart");
    find(".field").focus();

    assert
      .dom(docEl)
      .doesNotHaveClass("keyboard-visible", "no phantom keyboard layout");
  });

  test("tapping directly into a field does predict", async function (assert) {
    await learnKeyboardHeight();

    touch(find(".field"), "touchstart");
    find(".field").focus();

    assert.dom(docEl).hasClass("keyboard-visible");
  });

  test("a programmatic focus with no preceding touch does not predict", async function (assert) {
    await learnKeyboardHeight();

    find(".field").focus();

    assert
      .dom(docEl)
      .doesNotHaveClass("keyboard-visible", "no phantom keyboard layout");
  });

  test("a programmatic focus right after an inferred hide restores the keyboard state", async function (assert) {
    editable.focus();
    setViewportKeyboard(300);
    await reportViewport();
    assert.dom(docEl).hasClass("keyboard-visible", "keyboard is confirmed");

    // e.g. a toolbar tap opening a modal: focus settles outside any editable
    // before the modal autofocuses its input, and that refocus cancels the
    // keyboard hide, so the unchanged viewport never reports back
    touch(find(".target"), "touchstart");
    editable.blur();
    await settled();
    assert.dom(docEl).doesNotHaveClass("keyboard-visible", "hide is inferred");

    find(".field").focus();
    assert
      .dom(docEl)
      .hasClass("keyboard-visible", "the interrupted state is restored");

    await settled();
    assert
      .dom(docEl)
      .hasClass("keyboard-visible", "the geometry-backed restore holds");
  });

  test("focusing a non-keyboard field does not predict a keyboard", async function (assert) {
    await learnKeyboardHeight();

    find("select").focus();
    assert
      .dom(docEl)
      .doesNotHaveClass("keyboard-visible", "a select opens a picker");

    find("[type=checkbox]").focus();
    assert
      .dom(docEl)
      .doesNotHaveClass("keyboard-visible", "a checkbox summons no keyboard");
  });

  test("a readonly editable does not predict a keyboard", async function (assert) {
    await learnKeyboardHeight();

    touch(find(".readonly"), "touchstart");
    find(".readonly").focus();

    assert
      .dom(docEl)
      .doesNotHaveClass("keyboard-visible", "readonly summons no keyboard");
  });

  test("window blur tears down the keyboard state immediately", function (assert) {
    docEl.classList.add("keyboard-visible");

    window.dispatchEvent(new Event("blur"));

    assert.dom(docEl).doesNotHaveClass("keyboard-visible");
  });

  test("window blur from browser chrome blurs the editor too", function (assert) {
    focusWithKeyboard();

    window.dispatchEvent(new Event("blur"));

    assert.dom(docEl).doesNotHaveClass("keyboard-visible");
    assert
      .dom(editable)
      .isNotFocused("focus is released so a later tap can refocus normally");
  });

  test("window blur from backgrounding keeps the editor focused", function (assert) {
    focusWithKeyboard();

    // an app switch / lock hides the page; the OS restores focus on return
    Object.defineProperty(document, "visibilityState", {
      configurable: true,
      get: () => "hidden",
    });
    teardown.push(() => delete document.visibilityState);

    window.dispatchEvent(new Event("blur"));

    assert.dom(docEl).doesNotHaveClass("keyboard-visible");
    assert.dom(editable).isFocused("focus is left for the OS to restore");
  });

  test("window blur explained by a page touch keeps the editor focused", function (assert) {
    focusWithKeyboard();

    // e.g. a tap on an upload button opening a file picker
    touch(editable, "touchstart");
    window.dispatchEvent(new Event("blur"));

    assert.dom(docEl).doesNotHaveClass("keyboard-visible");
    assert.dom(editable).isFocused();
  });
});
