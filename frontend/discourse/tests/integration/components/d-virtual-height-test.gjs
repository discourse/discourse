import { getOwner } from "@ember/owner";
import { click, find, findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import DVirtualHeight from "discourse/components/d-virtual-height";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

// touch dispatch is synchronous so wall-clock gaps between events can't
// exceed the recent-touch window under a slow test runner
function touch(el, type, props = {}) {
  const event = new Event(type, { bubbles: true });
  Object.assign(event, props);
  el.dispatchEvent(event);
}

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
    const editableEl = find("textarea");

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
    const editableEl = find("textarea");

    editableEl.focus();
    docEl.classList.add("keyboard-visible");

    touch(find(".inert-content"), "touchstart");
    editableEl.blur();

    assert
      .dom(docEl)
      .doesNotHaveClass("keyboard-visible", "torn down before any timers run");
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
    const editableEl = find("textarea");
    const inputEl = find("input");

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
    const editableEl = find("textarea");
    const target = find(".target");

    let activations = 0;
    target.addEventListener("click", () => activations++);

    editableEl.focus();
    docEl.classList.add("keyboard-visible");

    touch(find(".inert-content"), "touchstart");
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
    const editableEl = find("textarea");
    const target = find(".target");

    let activations = 0;
    target.addEventListener("click", () => activations++);

    editableEl.focus();
    docEl.classList.add("keyboard-visible");

    touch(find(".inert-content"), "touchstart", {
      touches: [{ clientX: 0, clientY: 0 }],
    });
    touch(find(".inert-content"), "touchend", {
      changedTouches: [{ clientX: 0, clientY: 120 }],
    });
    editableEl.blur();
    assert.dom(docEl).doesNotHaveClass("keyboard-visible");

    await click("#ember-testing .target");
    assert.strictEqual(activations, 1, "drags synthesize no click to swallow");
  });

  test("a new touch releases the ghost click suppression", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <div class="inert-content">plain text</div>
        <button type="button" class="target">target</button>
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = find("textarea");
    const target = find(".target");

    let activations = 0;
    target.addEventListener("click", () => activations++);

    editableEl.focus();
    docEl.classList.add("keyboard-visible");

    touch(find(".inert-content"), "touchstart");
    editableEl.blur();
    assert.dom(docEl).doesNotHaveClass("keyboard-visible");

    // a deliberate follow-up tap within the ghost window
    touch(find(".target"), "touchstart");
    await click("#ember-testing .target");
    assert.strictEqual(activations, 1, "the new tap's click lands");
  });

  test("tapping back into an editable right after a dismiss restores the keyboard state", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <div class="inert-content">plain text</div>
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = find("textarea");

    // a real keyboard shrinks the viewport, setting the keyboard-sized height
    editableEl.focus();
    Object.defineProperty(window.visualViewport, "height", {
      configurable: true,
      value: window.innerHeight - 300,
    });
    window.visualViewport.dispatchEvent(new Event("resize"));
    await settled();
    const keyboardVh = docEl.style.getPropertyValue("--composer-vh");
    assert.dom(docEl).hasClass("keyboard-visible");

    touch(find(".inert-content"), "touchstart");
    editableEl.blur();
    assert.dom(docEl).doesNotHaveClass("keyboard-visible");

    const appEvents = getOwner(this).lookup("service:app-events");
    const received = [];
    const recorder = (visible) => received.push(visible);
    appEvents.on("keyboard-visibility-change", recorder);

    try {
      touch(editableEl, "touchstart");
      editableEl.focus();

      assert.dom(docEl).hasClass("keyboard-visible");
      assert.strictEqual(
        docEl.style.getPropertyValue("--composer-vh"),
        keyboardVh,
        "the keyboard-sized composer height is restored"
      );
      assert.deepEqual(received, [true]);
    } finally {
      appEvents.off("keyboard-visibility-change", recorder);
      delete window.visualViewport.height;
    }
  });

  test("a restored keyboard state reverts when the keyboard stays hidden", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <div class="inert-content">plain text</div>
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = find("textarea");

    editableEl.focus();

    try {
      // a real keyboard: the viewport reports shorter than the window
      Object.defineProperty(window.visualViewport, "height", {
        value: window.innerHeight - 300,
        configurable: true,
      });
      window.visualViewport.dispatchEvent(new Event("resize"));
      await settled();
      assert.dom(docEl).hasClass("keyboard-visible", "keyboard is confirmed");

      // the keyboard leaves the geometry, dismissed by an inert tap
      delete window.visualViewport.height;
      touch(find(".inert-content"), "touchstart");
      editableEl.blur();
      assert.dom(docEl).doesNotHaveClass("keyboard-visible");

      // the user taps back into the field
      touch(editableEl, "touchstart");
      editableEl.focus();
      assert.dom(docEl).hasClass("keyboard-visible", "snapshot restores");

      await settled();
      assert
        .dom(docEl)
        .doesNotHaveClass(
          "keyboard-visible",
          "a restore the viewport geometry contradicts reverts"
        );
    } finally {
      delete window.visualViewport.height;
    }
  });

  test("a restored keyboard state is kept while the viewport still reports one", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <div class="inert-content">plain text</div>
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = find("textarea");

    editableEl.focus();

    try {
      Object.defineProperty(window.visualViewport, "height", {
        value: window.innerHeight - 300,
        configurable: true,
      });
      window.visualViewport.dispatchEvent(new Event("resize"));
      await settled();
      assert.dom(docEl).hasClass("keyboard-visible", "keyboard is confirmed");

      // dismissed and refocused mid-hide: the keyboard never actually left
      touch(find(".inert-content"), "touchstart");
      editableEl.blur();
      assert.dom(docEl).doesNotHaveClass("keyboard-visible");

      // the user taps back into the field
      touch(editableEl, "touchstart");
      editableEl.focus();
      assert.dom(docEl).hasClass("keyboard-visible", "snapshot restores");

      await settled();
      assert
        .dom(docEl)
        .hasClass("keyboard-visible", "the geometry-backed restore holds");
    } finally {
      delete window.visualViewport.height;
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
    const editableEl = find("textarea");
    const inputEl = find("input");

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
      // a gesture-driven focus (a tap raises the keyboard)
      touch(inputEl, "touchstart");
      inputEl.focus();

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

      touch(editableEl, "touchstart");
      editableEl.focus();
      assert
        .dom(docEl)
        .doesNotHaveClass(
          "keyboard-visible",
          "prediction stays disabled until a real keyboard is seen"
        );
    } finally {
      appEvents.off("keyboard-visibility-change", recorder);
    }
  });

  test("tapping a control that focuses another field does not predict", async function (assert) {
    // a chooser: tapping the trigger opens it and programmatically focuses a
    // filter input, which raises no keyboard
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <button type="button" class="chooser-trigger">open</button>
        <input type="text" class="chooser-filter" />
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = find("textarea");

    // learn a keyboard height from a real gesture, then dismiss
    touch(editableEl, "touchstart");
    editableEl.focus();
    docEl.classList.add("keyboard-visible");
    getOwner(this).lookup("service:app-events").trigger("keyboard:will-hide");
    window.visualViewport.dispatchEvent(new Event("resize"));
    await settled();

    // the tap lands on the trigger; focus lands on the filter input
    touch(find(".chooser-trigger"), "touchstart");
    find(".chooser-filter").focus();
    assert
      .dom(docEl)
      .doesNotHaveClass("keyboard-visible", "no phantom keyboard layout");
  });

  test("tapping directly into a field does predict", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <input type="text" class="chooser-filter" />
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = find("textarea");
    const filterEl = find(".chooser-filter");

    touch(editableEl, "touchstart");
    editableEl.focus();
    docEl.classList.add("keyboard-visible");
    getOwner(this).lookup("service:app-events").trigger("keyboard:will-hide");
    window.visualViewport.dispatchEvent(new Event("resize"));
    await settled();

    // the tap lands on the filter input itself — a keyboard is expected
    touch(filterEl, "touchstart");
    filterEl.focus();
    assert.dom(docEl).hasClass("keyboard-visible");
  });

  test("focusing a non-keyboard field does not predict a keyboard", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <select><option>a</option></select>
        <input type="checkbox" />
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = find("textarea");

    editableEl.focus();
    docEl.classList.add("keyboard-visible");

    const appEvents = getOwner(this).lookup("service:app-events");
    appEvents.trigger("keyboard:will-hide");
    window.visualViewport.dispatchEvent(new Event("resize"));
    await settled();

    find("select").focus();
    assert
      .dom(docEl)
      .doesNotHaveClass("keyboard-visible", "a select opens a picker");

    find("[type=checkbox]").focus();
    assert
      .dom(docEl)
      .doesNotHaveClass("keyboard-visible", "a checkbox summons no keyboard");
  });

  test("a programmatic focus with no preceding touch does not predict", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <input type="text" />
      </template>
    );

    const docEl = document.documentElement;
    const inputEl = find("input");

    // a keyboard height is on record, then the keyboard is dismissed
    docEl.classList.add("keyboard-visible");
    getOwner(this).lookup("service:app-events").trigger("keyboard:will-hide");
    window.visualViewport.dispatchEvent(new Event("resize"));
    await settled();

    // no touch precedes this focus — the browser raises no keyboard for it
    inputEl.focus();
    assert
      .dom(docEl)
      .doesNotHaveClass("keyboard-visible", "no phantom keyboard layout");
  });

  test("a readonly editable does not predict a keyboard", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <textarea readonly></textarea>
      </template>
    );

    const docEl = document.documentElement;
    const [editableEl, readonlyEl] = findAll("#ember-testing textarea");

    touch(editableEl, "touchstart");
    editableEl.focus();
    docEl.classList.add("keyboard-visible");
    getOwner(this).lookup("service:app-events").trigger("keyboard:will-hide");
    window.visualViewport.dispatchEvent(new Event("resize"));
    await settled();

    touch(readonlyEl, "touchstart");
    readonlyEl.focus();
    assert
      .dom(docEl)
      .doesNotHaveClass("keyboard-visible", "readonly summons no keyboard");
  });

  test("the dismissing tap's click passes through when it lands on the touched element", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <div class="inert-content" role="none">plain text</div>
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = find("textarea");
    const inertEl = find(".inert-content");

    let activations = 0;
    inertEl.addEventListener("click", () => activations++);

    editableEl.focus();
    docEl.classList.add("keyboard-visible");

    // the reflow did not move this element out from under the finger, so its
    // own click must still activate it
    touch(inertEl, "touchstart");
    editableEl.blur();

    await click("#ember-testing .inert-content");
    assert.strictEqual(activations, 1, "the touched element's click lands");
  });

  test("window blur tears down the keyboard state immediately", async function (assert) {
    await render(<template><DVirtualHeight /></template>);

    const docEl = document.documentElement;
    docEl.classList.add("keyboard-visible");

    window.dispatchEvent(new Event("blur"));

    assert.dom(docEl).doesNotHaveClass("keyboard-visible");
  });

  test("window blur from browser chrome blurs the editor too", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = find("textarea");

    editableEl.focus();
    docEl.classList.add("keyboard-visible");

    window.dispatchEvent(new Event("blur"));

    assert.dom(docEl).doesNotHaveClass("keyboard-visible");
    assert
      .dom(editableEl)
      .isNotFocused("focus is released so a later tap can refocus normally");
  });

  test("window blur from backgrounding keeps the editor focused", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = find("textarea");

    editableEl.focus();
    docEl.classList.add("keyboard-visible");

    // an app switch / lock hides the page; the OS restores focus on return
    const visibility = Object.getOwnPropertyDescriptor(
      Document.prototype,
      "visibilityState"
    );
    Object.defineProperty(document, "visibilityState", {
      configurable: true,
      get: () => "hidden",
    });

    try {
      window.dispatchEvent(new Event("blur"));
      assert.dom(docEl).doesNotHaveClass("keyboard-visible");
      assert.dom(editableEl).isFocused("focus is left for the OS to restore");
    } finally {
      if (visibility) {
        Object.defineProperty(document, "visibilityState", visibility);
      } else {
        delete document.visibilityState;
      }
    }
  });

  test("window blur explained by a page touch keeps the editor focused", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = find("textarea");

    editableEl.focus();
    docEl.classList.add("keyboard-visible");

    // e.g. a tap on an upload button opening a file picker
    touch(editableEl, "touchstart");
    window.dispatchEvent(new Event("blur"));

    assert.dom(docEl).doesNotHaveClass("keyboard-visible");
    assert.dom(editableEl).isFocused();
  });

  test("a cancelled touch does not arm the ghost click suppression", async function (assert) {
    await render(
      <template>
        <DVirtualHeight />
        <textarea></textarea>
        <div class="inert-content">plain text</div>
        <button type="button" class="target">target</button>
      </template>
    );

    const docEl = document.documentElement;
    const editableEl = find("textarea");
    const target = find(".target");

    let activations = 0;
    target.addEventListener("click", () => activations++);

    editableEl.focus();
    docEl.classList.add("keyboard-visible");

    touch(find(".inert-content"), "touchstart");
    touch(find(".inert-content"), "touchcancel");
    editableEl.blur();
    assert.dom(docEl).doesNotHaveClass("keyboard-visible");

    await click("#ember-testing .target");
    assert.strictEqual(activations, 1, "no ghost click is expected");
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
