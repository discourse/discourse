import { getOwner } from "@ember/application";

export async function waitForClosedKeyboard(context) {
  return new Promise((resolve) => {
    if (!window.visualViewport) {
      return resolve();
    }

    const owner = getOwner(context);
    const site = owner.lookup("service:site");
    const capabilities = owner.lookup("service:capabilities");

    if (!capabilities.isIpadOS && site.desktopView) {
      return resolve();
    }

    if (!document.documentElement.classList.contains("keyboard-visible")) {
      return resolve();
    }

    const safeguard = setTimeout(() => {
      // eslint-disable-next-line no-console
      console.warn("Keyboard visibility didnt change after 1s.");

      resolve();
    }, 1000);

    const initialWindowHeight = window.innerHeight;

    const onViewportResize = () => {
      clearTimeout(safeguard);

      if ("virtualKeyboard" in navigator) {
        if (navigator.virtualKeyboard.boundingRect.height > 0) {
          // eslint-disable-next-line no-console
          console.warn("Expected virtual keyboard to be closed but it wasn't.");
          return resolve();
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
          return resolve();
        }
      } else {
        let viewportWindowDiff =
          initialWindowHeight - window.visualViewport.height;
        if (viewportWindowDiff > 0) {
          // eslint-disable-next-line no-console
          console.warn("Expected virtual keyboard to be closed but it wasn't.");
          return resolve();
        }
      }

      return resolve();
    };

    window.visualViewport.addEventListener("resize", onViewportResize, {
      once: true,
      passive: true,
    });
  });
}
