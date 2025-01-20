/*
  In iOS Safari, setting user-scalable=no doesn't actually prevent the user from zooming in.
  But, it does prevent the annoying 'auto zoom' when focussing input fields with small font-sizes.
*/
export default {
  initialize(container) {
    if (!container.lookup("service:capabilities").isIOS) {
      return;
    }

    const viewport = document.querySelector("meta[name=viewport]");
    if (viewport) {
      const current = viewport.getAttribute("content");
      viewport.setAttribute(
        "content",
        current.replace("user-scalable=yes", "user-scalable=no")
      );
    }
  },
};
