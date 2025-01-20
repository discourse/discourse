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
    if (caps.isIOS) {
      // In iOS Safari, setting user-scalable=no doesn't actually prevent the user from zooming in.
      // But, it does prevent the annoying 'auto zoom' when focussing input fields with small font-sizes.
      value += ", user-scalable=no";
    }

    if (!caps.isSafari) {
      // Safari prints a big red warning because it doesn't support this property.
      // Add it for all other browsers.
      value += ", interactive-widget=resizes-content";
    }

    viewport.setAttribute("content", value);
  },
};
