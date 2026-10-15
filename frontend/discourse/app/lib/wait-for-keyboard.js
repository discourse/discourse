const KEYBOARD_DETECT_THRESHOLD = 150;

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

  // the keyboard height is now applied optimistically, ahead of the viewport
  // settling, so the class alone no longer means the keyboard has gone —
  // wait on the geometry the callers actually measure against
  const initialWindowHeight = window.innerHeight;

  const keyboardClosed = () => {
    if ("virtualKeyboard" in navigator) {
      return navigator.virtualKeyboard.boundingRect.height === 0;
    }

    if (capabilitiesService.isFirefox && capabilitiesService.isAndroid) {
      return (
        Math.abs(
          initialWindowHeight -
            Math.min(window.innerHeight, window.visualViewport.height)
        ) <= KEYBOARD_DETECT_THRESHOLD
      );
    }

    // same definition of "no keyboard" the detection logic uses; a persistent
    // sub-threshold offset (e.g. a browser toolbar) is not the keyboard
    return (
      window.innerHeight - window.visualViewport.height <=
      KEYBOARD_DETECT_THRESHOLD
    );
  };

  if (keyboardClosed()) {
    return;
  }

  await new Promise((resolve) => {
    const onResize = () => {
      if (keyboardClosed()) {
        settle();
      }
    };

    const timeout = setTimeout(() => {
      // eslint-disable-next-line no-console
      console.warn("Keyboard visibility didn't change after 1s.");
      settle();
    }, 1000);

    function settle() {
      clearTimeout(timeout);
      window.visualViewport.removeEventListener("resize", onResize);
      resolve();
    }

    window.visualViewport.addEventListener("resize", onResize);
  });
}
