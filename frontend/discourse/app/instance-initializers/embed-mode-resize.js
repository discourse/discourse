import EmbedMode from "discourse/lib/embed-mode";

let resizeObserver;

function postHeight() {
  if (parent === window) {
    return;
  }
  parent.postMessage(
    { type: "discourse-resize", height: document.body.scrollHeight },
    "*"
  );
}

export default {
  initialize() {
    if (!EmbedMode.enabled) {
      return;
    }

    resizeObserver = new ResizeObserver(postHeight);
    resizeObserver.observe(document.body);
  },

  teardown() {
    resizeObserver?.disconnect();
    resizeObserver = null;
  },
};
