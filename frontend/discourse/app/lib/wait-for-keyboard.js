export async function waitForClosedKeyboard(siteService, capabilitiesService) {
  if (!window.visualViewport) {
    return;
  }

  if (!capabilitiesService.isIpadOS && siteService.desktopView) {
    return;
  }

  if (!document.documentElement.classList.contains("keyboard-visible")) {
    return;
  }

  let timeout;
  const initialWindowHeight = window.innerHeight;
  let observer;

  await Promise.race([
    new Promise((resolve) => {
      timeout = setTimeout(() => {
        // eslint-disable-next-line no-console
        console.warn("Keyboard visibility didn't change after 1s.");

        resolve();
      }, 1000);
    }),
    new Promise((resolve) => {
      observer = new MutationObserver(() => {
        if (!document.documentElement.classList.contains("keyboard-visible")) {
          resolve();
        }
      });

      observer.observe(document.documentElement, {
        attributes: true,
        attributeFilter: ["class"],
      });
    }),
  ]);

  clearTimeout(timeout);
  observer?.disconnect();

  if ("virtualKeyboard" in navigator) {
    if (navigator.virtualKeyboard.boundingRect.height > 0) {
      // eslint-disable-next-line no-console
      console.warn("Expected virtual keyboard to be closed but it wasn't.");
      return;
    }
  } else if (capabilitiesService.isFirefox && capabilitiesService.isAndroid) {
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
