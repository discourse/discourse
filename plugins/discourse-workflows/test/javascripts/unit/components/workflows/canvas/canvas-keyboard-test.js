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

function dispatchKey(key, opts = {}) {
  const event = new KeyboardEvent("keydown", {
    key,
    code: opts.code ?? "",
    metaKey: opts.meta ?? false,
    ctrlKey: opts.ctrl ?? false,
    shiftKey: opts.shift ?? false,
    bubbles: true,
    cancelable: true,
  });
  document.dispatchEvent(event);
  return event;
}

module("Unit | Canvas Keyboard", function (hooks) {
  setupTest(hooks);

  let keyboard;

  hooks.afterEach(function () {
    keyboard?.teardown();
    keyboard = null;
  });

  test("pauses Discourse shortcuts on setup", function (assert) {
    const service = fakeKeyboardShortcutsService();
    keyboard = setupCanvasKeyboard(service, {});

    assert.deepEqual(service.paused, ["-", "="]);
  });

  test("teardown unpauses shortcuts and removes listener", function (assert) {
    const service = fakeKeyboardShortcutsService();
    let called = false;
    keyboard = setupCanvasKeyboard(service, {
      onZoomIn() {
        called = true;
      },
    });

    keyboard.teardown();
    keyboard = null;

    dispatchKey("=");
    assert.false(called, "handler no longer fires after teardown");
    assert.deepEqual(service.paused, [], "shortcuts unpaused");
  });

  test("Ctrl+Z triggers onUndo", function (assert) {
    let undone = false;
    const service = fakeKeyboardShortcutsService();
    keyboard = setupCanvasKeyboard(service, {
      onUndo() {
        undone = true;
      },
    });

    dispatchKey("z", { ctrl: true });
    assert.true(undone);
  });

  test("Ctrl+Shift+Z triggers onRedo", function (assert) {
    let redone = false;
    const service = fakeKeyboardShortcutsService();
    keyboard = setupCanvasKeyboard(service, {
      onRedo() {
        redone = true;
      },
    });

    dispatchKey("z", { ctrl: true, shift: true });
    assert.true(redone);
  });

  test("Ctrl+Y triggers onRedo", function (assert) {
    let redone = false;
    const service = fakeKeyboardShortcutsService();
    keyboard = setupCanvasKeyboard(service, {
      onRedo() {
        redone = true;
      },
    });

    dispatchKey("y", { ctrl: true });
    assert.true(redone);
  });

  test("Ctrl+C triggers onCopy", function (assert) {
    let copied = false;
    const service = fakeKeyboardShortcutsService();
    keyboard = setupCanvasKeyboard(service, {
      onCopy() {
        copied = true;
      },
    });

    dispatchKey("c", { meta: true });
    assert.true(copied);
  });

  test("Ctrl+V triggers onPaste", function (assert) {
    let pasted = false;
    const service = fakeKeyboardShortcutsService();
    keyboard = setupCanvasKeyboard(service, {
      onPaste() {
        pasted = true;
      },
    });

    dispatchKey("v", { meta: true });
    assert.true(pasted);
  });

  test("Delete and Backspace trigger onDelete", function (assert) {
    let deleteCount = 0;
    const service = fakeKeyboardShortcutsService();
    keyboard = setupCanvasKeyboard(service, {
      onDelete() {
        deleteCount++;
      },
    });

    dispatchKey("Delete");
    dispatchKey("Backspace");
    assert.strictEqual(deleteCount, 2);
  });

  test("Escape triggers onEscape", function (assert) {
    let escaped = false;
    const service = fakeKeyboardShortcutsService();
    keyboard = setupCanvasKeyboard(service, {
      onEscape() {
        escaped = true;
      },
    });

    dispatchKey("Escape");
    assert.true(escaped);
  });

  test("+ and = trigger onZoomIn, - triggers onZoomOut", function (assert) {
    let zoomInCount = 0;
    let zoomOutCount = 0;
    const service = fakeKeyboardShortcutsService();
    keyboard = setupCanvasKeyboard(service, {
      onZoomIn() {
        zoomInCount++;
      },
      onZoomOut() {
        zoomOutCount++;
      },
    });

    dispatchKey("+");
    dispatchKey("=");
    dispatchKey("-");
    assert.strictEqual(zoomInCount, 2);
    assert.strictEqual(zoomOutCount, 1);
  });

  test("Digit1 triggers onFitToView, Digit2 triggers onAutoLayout", function (assert) {
    let fitCalled = false;
    let layoutCalled = false;
    const service = fakeKeyboardShortcutsService();
    keyboard = setupCanvasKeyboard(service, {
      onFitToView() {
        fitCalled = true;
      },
      onAutoLayout() {
        layoutCalled = true;
      },
    });

    dispatchKey("1", { code: "Digit1" });
    dispatchKey("2", { code: "Digit2" });
    assert.true(fitCalled);
    assert.true(layoutCalled);
  });

  test("ignores keystrokes on input elements", function (assert) {
    let called = false;
    const service = fakeKeyboardShortcutsService();
    keyboard = setupCanvasKeyboard(service, {
      onDelete() {
        called = true;
      },
    });

    const input = document.createElement("input");
    document.getElementById("qunit-fixture").appendChild(input);

    const event = new KeyboardEvent("keydown", {
      key: "Delete",
      bubbles: true,
    });
    input.dispatchEvent(event);

    assert.false(called, "handler skipped for input elements");
  });

  test("ignores keystrokes on textarea elements", function (assert) {
    let called = false;
    const service = fakeKeyboardShortcutsService();
    keyboard = setupCanvasKeyboard(service, {
      onDelete() {
        called = true;
      },
    });

    const textarea = document.createElement("textarea");
    document.getElementById("qunit-fixture").appendChild(textarea);

    const event = new KeyboardEvent("keydown", {
      key: "Delete",
      bubbles: true,
    });
    textarea.dispatchEvent(event);

    assert.false(called, "handler skipped for textarea elements");
  });

  test("missing action callbacks do not throw", function (assert) {
    const service = fakeKeyboardShortcutsService();
    keyboard = setupCanvasKeyboard(service, {});

    dispatchKey("z", { ctrl: true });
    dispatchKey("Delete");
    dispatchKey("+");
    dispatchKey("1", { code: "Digit1" });

    assert.true(true, "no errors thrown for missing callbacks");
  });

  test("teardown tolerates uninitialized keyboard shortcuts service", function (assert) {
    const service = {
      pause() {},
      unpause() {
        throw new Error("not initialized");
      },
    };
    keyboard = setupCanvasKeyboard(service, {});
    keyboard.teardown();
    keyboard = null;

    assert.true(true, "teardown completed despite error");
  });
});
