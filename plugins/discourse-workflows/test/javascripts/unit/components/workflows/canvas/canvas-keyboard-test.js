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

  test("Ctrl+C triggers onCopy", function (assert) {
    let copied = false;
    keyboard = setup({ onCopy: () => (copied = true) });

    press("c", { meta: true });
    assert.true(copied);
  });

  test("Ctrl+V triggers onPaste", function (assert) {
    let pasted = false;
    keyboard = setup({ onPaste: () => (pasted = true) });

    press("v", { meta: true });
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
