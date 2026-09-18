import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { waitForClosedKeyboard } from "discourse/lib/wait-for-keyboard";

const SITE_MOBILE = { desktopView: false };
const CAPS = { isIpadOS: false, isFirefox: false, isAndroid: false };

module("Unit | Lib | wait-for-keyboard", function (hooks) {
  setupTest(hooks);

  // drive the closed/open signal through whichever primitive the running
  // browser uses (Chrome exposes navigator.virtualKeyboard; others report
  // via the visual viewport height), so the test is deterministic anywhere
  const usesVirtualKeyboard = "virtualKeyboard" in navigator;

  function setKeyboardHeight(px) {
    if (usesVirtualKeyboard) {
      Object.defineProperty(navigator.virtualKeyboard, "boundingRect", {
        configurable: true,
        get: () => new DOMRect(0, 0, 0, px),
      });
    } else {
      Object.defineProperty(window.visualViewport, "height", {
        configurable: true,
        value: window.innerHeight - px,
      });
    }
  }

  hooks.afterEach(function () {
    document.documentElement.classList.remove("keyboard-visible");
    if (usesVirtualKeyboard) {
      delete navigator.virtualKeyboard.boundingRect;
    } else {
      delete window.visualViewport.height;
    }
  });

  test("resolves immediately when the keyboard class is absent", async function (assert) {
    setKeyboardHeight(300);
    await waitForClosedKeyboard(SITE_MOBILE, CAPS);
    assert.true(true, "did not hang on the still-open keyboard");
  });

  test("resolves immediately when the keyboard already reads closed", async function (assert) {
    document.documentElement.classList.add("keyboard-visible");
    setKeyboardHeight(0);
    await waitForClosedKeyboard(SITE_MOBILE, CAPS);
    assert.true(true, "a zero-height keyboard counts as closed");
  });

  test("waits for the keyboard to actually close before resolving", async function (assert) {
    document.documentElement.classList.add("keyboard-visible");
    setKeyboardHeight(300);

    let resolved = false;
    const done = waitForClosedKeyboard(SITE_MOBILE, CAPS).then(
      () => (resolved = true)
    );

    await Promise.resolve();
    assert.false(resolved, "still pending while the keyboard occupies space");

    // the OS hide animation completes and the viewport settles
    setKeyboardHeight(0);
    window.visualViewport.dispatchEvent(new Event("resize"));

    await done;
    assert.true(resolved, "resolves once the keyboard reports closed");
  });
});
