import { schedule } from "@ember/runloop";
import EmbedMode from "discourse/lib/embed-mode";
import { withPluginApi } from "discourse/lib/plugin-api";
import blogOrigin from "discourse/plugins/blog/discourse/lib/blog-origin";

let paletteListener;

export default {
  name: "discourse-blog-discussion",

  initialize(container) {
    const settings = container.lookup("service:site-settings");
    // Boots other than the embed must not keep a listener from an earlier boot.
    window.removeEventListener("message", paletteListener);
    paletteListener = null;
    const root = document.documentElement;
    const embedClass = "discourse-blog-discussion";
    const requestedClass = new URLSearchParams(window.location.search).get(
      "class_name"
    );
    if (
      !settings.blog_enabled ||
      !EmbedMode.enabled ||
      (!root.classList.contains(embedClass) && requestedClass !== embedClass)
    ) {
      return;
    }

    // An iframe-only reload can lose the server class when its referrer changes.
    root.classList.add(embedClass);

    const parentOrigin = blogOrigin(
      container.lookup("service:site").blog_base_url
    );

    withPluginApi((api) => {
      api.onPageChange(() => {
        schedule("afterRender", () => {
          if (parentOrigin) {
            window.parent.postMessage(
              { type: "discourse-blog-ready" },
              parentOrigin
            );
          }
        });
      });
    });

    // The blog owns the design, so it sends its palette once the frame is ready.
    paletteListener = (event) => {
      if (
        event.origin !== parentOrigin ||
        event.data?.type !== "discourse-blog-palette"
      ) {
        return;
      }

      const palette = {
        accent: event.data.accent,
        paper: event.data.paper,
        ink: event.data.ink,
      };
      const colors = Object.entries(palette);
      if (!colors.every(([, color]) => /^#[0-9a-f]{6}$/i.test(color))) {
        return;
      }

      for (const [name, color] of colors) {
        root.style.setProperty(`--blog-${name}-color`, color);
      }
    };
    window.addEventListener("message", paletteListener);
  },
};
