import { getOwner } from "@ember/owner";

export async function waitForClosedKeyboard(context) {
  if (!window.visualViewport) {
    return;
  }

  const owner = getOwner(context);
  const site = owner.lookup("service:site");
  const capabilities = owner.lookup("service:capabilities");

  if (!capabilities.isIpadOS && site.desktopView) {
    return;
  }

  if (!document.documentElement.classList.contains("keyboard-visible")) {
    return;
  }

  let timeout;
  let viewportListener;
  const initialWindowHeight = window.innerHeight;

  await Promise.race([
    new Promise((resolve) => {
      timeout = setTimeout(() => {
        // eslint-disable-next-line no-console
        console.warn("Keyboard visibility didn't change after 1s.");

        resolve();
      }, 1000);
    }),
    new Promise((resolve) =>
      window.visualViewport.addEventListener(
        "resize",
        (viewportListener = resolve),
        { once: true, passive: true }
      )
    ),
  ]);

  clearTimeout(timeout);
  window.visualViewport.removeEventListener("resize", viewportListener);

  if ("virtualKeyboard" in navigator) {
    if (navigator.virtualKeyboard.boundingRect.height > 0) {
      // eslint-disable-next-line no-console
      console.warn("Expected virtual keyboard to be closed but it wasn't.");
      return;
    }
  } else if (capabilities.isFirefox && capabilities.isAndroid) {
    const KEYBOARD_DETECT_THRESHOLD = 150;
    if (
      Math.abs(
        initialWindowHeight -
          Math.min(window.innerHeight, window.visualViewport.height)
      ) > KEYBOARD_DETECT_THRESHOLD
    ) {
      // eslint-disable-next-line no-console
      console.warn("Expected virtual keyboard to be closed but it wasn't.");
      return;
    }
  } else {
    let viewportWindowDiff = initialWindowHeight - window.visualViewport.height;
    if (viewportWindowDiff > 0) {
      // eslint-disable-next-line no-console
      console.warn("Expected virtual keyboard to be closed but it wasn't.");
      return;
    }
  }
}
