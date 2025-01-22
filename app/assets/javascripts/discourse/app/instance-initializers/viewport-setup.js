let done = false;

export default {
  initialize(container) {
    if (done) {
      return;
    }
    done = true;

    const caps = container.lookup("service:capabilities");
    const viewport = document.querySelector("meta[name=viewport]");
    if (!viewport) {
      return;
    }

    let value = viewport.getAttribute("content");

    if (!caps.isSafari) {
      // Safari prints a big red warning because it doesn't support this property.
      // Add it for all other browsers.
      value += ", interactive-widget=resizes-content";
    }

    if (caps.isIOS) {
      // iOS 'auto-zooms' into inputs with font sizes smaller than 16px. To prevent this,
      // we use two different strategies.
      if (caps.isiOSPWA || caps.isAppWebview) {
        // For PWA/Hub, we lock the viewport zoom temporarily during `focusin` events.
        // Unfortunately this doesn't catch the case when an input is already autofocussed, but the
        // keyboard isn't open yet. But it's better than nothing.
        this.lockViewportDuringFocus(viewport, value);
      } else {
        // In the full Safari browser, user-scalable=no doesn't actually prevent the user from zooming in.
        // So we can keep it in place all the time to prevent the auto-zoom.
        value += ", user-scalable=no";
      }
    }

    viewport.setAttribute("content", value);
  },

  lockViewportDuringFocus(viewport, initialValue) {
    let timer;

    window.addEventListener("focusin", (event) => {
      if (!["INPUT", "TEXTAREA"].includes(event.target.tagName)) {
        return;
      }

      viewport.setAttribute("content", `${initialValue}, user-scalable=no`);

      clearTimeout(timer);
      timer = setTimeout(
        () => viewport.setAttribute("content", initialValue),
        100
      );
    });
  },
};
