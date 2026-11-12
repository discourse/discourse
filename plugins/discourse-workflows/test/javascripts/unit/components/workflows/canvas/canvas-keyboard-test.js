import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { setupCanvasKeyboard } from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas/canvas-keyboard";

function fakeKeyboardShortcutsService() {
  return {
    paused: [],
    pause(keys) {
      this.paused.push(...keys);
    },
    unpause(keys) {
      this.paused = this.paused.filter((k) => !keys.includes(k));
    },
  };
}

module("Unit | Canvas Keyboard", function (hooks) {
  setupTest(hooks);

  let keyboard;
  let canvasElement;
  let service;

  hooks.beforeEach(function () {
    service = fakeKeyboardShortcutsService();
    canvasElement = document.createElement("div");
    document.getElementById("qunit-fixture").appendChild(canvasElement);
  });

  hooks.afterEach(function () {
    keyboard?.teardown();
    keyboard = null;
  });

  function setup(actions) {
    return setupCanvasKeyboard(service, actions, canvasElement);
  }

  function press(key, opts = {}) {
    const event = new KeyboardEvent("keydown", {
      key,
      code: opts.code ?? "",
      metaKey: opts.meta ?? false,
      ctrlKey: opts.ctrl ?? false,
      shiftKey: opts.shift ?? false,
      bubbles: true,
      cancelable: true,
    });
    (opts.target ?? canvasElement).dispatchEvent(event);
    return event;
  }

  function dispatchEvent(type, opts = {}) {
    const event = new Event(type, { bubbles: true, cancelable: true });
    (opts.target ?? canvasElement).dispatchEvent(event);
    return event;
  }

  test("pauses Discourse shortcuts on setup", function (assert) {
    keyboard = setup({});
    assert.deepEqual(service.paused, ["-", "="]);
  });

  test("teardown unpauses shortcuts and removes listener", function (assert) {
    let called = false;
    keyboard = setup({ onZoomIn: () => (called = true) });

    keyboard.teardown();
    keyboard = null;

    press("=");
    assert.false(called, "handler no longer fires after teardown");
    assert.deepEqual(service.paused, [], "shortcuts unpaused");
  });

  test("Ctrl+Z triggers onUndo", function (assert) {
    let undone = false;
    keyboard = setup({ onUndo: () => (undone = true) });

    press("z", { ctrl: true });
    assert.true(undone);
  });

  test("Ctrl+Shift+Z triggers onRedo", function (assert) {
    let redone = false;
    keyboard = setup({ onRedo: () => (redone = true) });

    press("z", { ctrl: true, shift: true });
    assert.true(redone);
  });

  test("Ctrl+Y triggers onRedo", function (assert) {
    let redone = false;
    keyboard = setup({ onRedo: () => (redone = true) });

    press("y", { ctrl: true });
    assert.true(redone);
  });

  test("Ctrl+C triggers onCopy and prevents native copy", function (assert) {
    let copied = false;
    keyboard = setup({ onCopy: () => (copied = true) });

    const event = press("c", { meta: true });
    assert.true(copied);
    assert.true(event.defaultPrevented, "native copy is prevented");
  });

  test("Ctrl+X triggers onCut and prevents native cut", function (assert) {
    let cut = false;
    keyboard = setup({ onCut: () => (cut = true) });

    const event = press("x", { meta: true });
    assert.true(cut);
    assert.true(event.defaultPrevented, "native cut is prevented");
  });

  test("native copy event triggers onCopy and prevents browser copy", function (assert) {
    let copied = false;
    keyboard = setup({ onCopy: () => (copied = true) });

    const event = dispatchEvent("copy");

    assert.true(copied);
    assert.true(event.defaultPrevented, "native copy is prevented");
  });

  test("native cut event triggers onCut and prevents browser cut", function (assert) {
    let cut = false;
    keyboard = setup({ onCut: () => (cut = true) });

    const event = dispatchEvent("cut");

    assert.true(cut);
    assert.true(event.defaultPrevented, "native cut is prevented");
  });

  test("paste event triggers onPaste", function (assert) {
    let pasted = false;
    keyboard = setup({ onPaste: () => (pasted = true) });

    dispatchEvent("paste");

    assert.true(pasted);
  });

  test("Delete and Backspace trigger onDelete", function (assert) {
    let deleteCount = 0;
    keyboard = setup({ onDelete: () => deleteCount++ });

    press("Delete");
    press("Backspace");
    assert.strictEqual(deleteCount, 2);
  });

  test("Escape triggers onEscape", function (assert) {
    let escaped = false;
    keyboard = setup({ onEscape: () => (escaped = true) });

    press("Escape");
    assert.true(escaped);
  });

  test("+ and = trigger onZoomIn, - triggers onZoomOut", function (assert) {
    let zoomInCount = 0;
    let zoomOutCount = 0;
    keyboard = setup({
      onZoomIn: () => zoomInCount++,
      onZoomOut: () => zoomOutCount++,
    });

    press("+");
    press("=");
    press("-");
    assert.strictEqual(zoomInCount, 2);
    assert.strictEqual(zoomOutCount, 1);
  });

  test("Digit1 triggers onFitToView, Digit2 triggers onAutoLayout", function (assert) {
    let fitCalled = false;
    let layoutCalled = false;
    keyboard = setup({
      onFitToView: () => (fitCalled = true),
      onAutoLayout: () => (layoutCalled = true),
    });

    press("1", { code: "Digit1" });
    press("2", { code: "Digit2" });
    assert.true(fitCalled);
    assert.true(layoutCalled);
  });

  test("ignores keystrokes on input elements", function (assert) {
    let called = false;
    keyboard = setup({ onDelete: () => (called = true) });

    const input = document.createElement("input");
    canvasElement.appendChild(input);
    press("Delete", { target: input });

    assert.false(called);
  });

  test("ignores keystrokes on textarea elements", function (assert) {
    let called = false;
    keyboard = setup({ onDelete: () => (called = true) });

    const textarea = document.createElement("textarea");
    canvasElement.appendChild(textarea);
    press("Delete", { target: textarea });

    assert.false(called);
  });

  test("ignores keystrokes on select elements", function (assert) {
    let called = false;
    keyboard = setup({ onDelete: () => (called = true) });

    const select = document.createElement("select");
    canvasElement.appendChild(select);
    press("Delete", { target: select });

    assert.false(called);
  });

  test("ignores paste events on textarea elements", function (assert) {
    let called = false;
    keyboard = setup({ onPaste: () => (called = true) });

    const textarea = document.createElement("textarea");
    canvasElement.appendChild(textarea);
    dispatchEvent("paste", { target: textarea });

    assert.false(called);
  });

  test("ignores copy and cut events on editable elements", function (assert) {
    let called = false;
    keyboard = setup({
      onCopy: () => (called = true),
      onCut: () => (called = true),
    });

    const editable = document.createElement("div");
    editable.contentEditable = "true";
    canvasElement.appendChild(editable);

    const copyEvent = dispatchEvent("copy", { target: editable });
    const cutEvent = dispatchEvent("cut", { target: editable });

    assert.false(called);
    assert.false(copyEvent.defaultPrevented, "native copy is allowed");
    assert.false(cutEvent.defaultPrevented, "native cut is allowed");
  });

  test("missing action callbacks do not throw", function (assert) {
    keyboard = setup({});

    press("z", { ctrl: true });
    press("Delete");
    press("+");
    press("1", { code: "Digit1" });

    assert.true(true, "no errors thrown");
  });

  test("teardown tolerates uninitialized keyboard shortcuts service", function (assert) {
    const brokenService = {
      pause() {},
      unpause() {
        throw new Error("not initialized");
      },
    };
    keyboard = setupCanvasKeyboard(brokenService, {}, canvasElement);
    keyboard.teardown();
    keyboard = null;

    assert.true(true, "teardown completed despite error");
  });
});
