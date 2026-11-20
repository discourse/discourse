import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { waitForClosedKeyboard } from "discourse/lib/wait-for-keyboard";

const SITE_MOBILE = { desktopView: false };
const CAPS = { isIpadOS: false, isFirefox: false, isAndroid: false };

module("Unit | Lib | wait-for-keyboard", function (hooks) {
  setupTest(hooks);

  function setKeyboardHeight(px) {
    Object.defineProperty(window.visualViewport, "height", {
      configurable: true,
      value: window.innerHeight - px,
    });
  }

  hooks.beforeEach(function () {
    this.virtualKeyboard = Object.getOwnPropertyDescriptor(
      navigator,
      "virtualKeyboard"
    );
    Object.defineProperty(navigator, "virtualKeyboard", {
      configurable: true,
      value: { overlaysContent: false, boundingRect: new DOMRect() },
    });
  });

  hooks.afterEach(function () {
    document.documentElement.classList.remove("keyboard-visible");
    delete window.visualViewport.height;
    if (this.virtualKeyboard) {
      Object.defineProperty(navigator, "virtualKeyboard", this.virtualKeyboard);
    } else {
      delete navigator.virtualKeyboard;
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

  test("waits for the viewport when virtual keyboard overlays are disabled", async function (assert) {
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

  test("waits for keyboard geometry when virtual keyboard overlays are enabled", async function (assert) {
    document.documentElement.classList.add("keyboard-visible");
    setKeyboardHeight(0);
    navigator.virtualKeyboard.overlaysContent = true;
    navigator.virtualKeyboard.boundingRect = new DOMRect(0, 0, 0, 300);

    let resolved = false;
    const done = waitForClosedKeyboard(SITE_MOBILE, CAPS).then(
      () => (resolved = true)
    );

    await Promise.resolve();
    assert.false(
      resolved,
      "an unchanged viewport does not imply a closed overlay keyboard"
    );

    navigator.virtualKeyboard.boundingRect = new DOMRect();
    window.visualViewport.dispatchEvent(new Event("resize"));

    await done;
    assert.true(resolved, "resolves once the overlay keyboard reports closed");
  });
});
