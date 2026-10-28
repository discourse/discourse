import EmbedMode from "discourse/lib/embed-mode";
import blogOrigin from "discourse/plugins/blog/discourse/lib/blog-origin";

let observer;
let frame;

export default {
  after: "discourse-blog-discussion",

  initialize(container) {
    const settings = container.lookup("service:site-settings");
    const origin = blogOrigin(settings.blog_url);
    if (
      !settings.blog_enabled ||
      !EmbedMode.enabled ||
      !document.documentElement.classList.contains(
        "discourse-blog-discussion"
      ) ||
      !origin
    ) {
      return;
    }

    const element = document.getElementById("main");
    if (!element) {
      return;
    }

    let previousHeight;
    // Core's initial resize notifications stop; replies and composer edits do not.
    observer = new ResizeObserver(() => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        const height = Math.ceil(
          Math.max(element.scrollHeight, element.getBoundingClientRect().height)
        );
        if (height !== previousHeight) {
          previousHeight = height;
          window.parent.postMessage(
            { type: "discourse-blog-resize", height },
            origin
          );
        }
      });
    });
    observer.observe(element, { box: "border-box" });
  },

  teardown() {
    observer?.disconnect();
    observer = null;
    cancelAnimationFrame(frame);
    frame = null;
  },
};
