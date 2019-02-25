import highlightSyntax from "discourse/lib/highlight-syntax";
import lightbox from "discourse/lib/lightbox";
import { setupLazyLoading } from "discourse/lib/lazy-load-images";
import { setTextDirections } from "discourse/lib/text-direction";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "post-decorations",
  initialize(container) {
    withPluginApi("0.1", api => {
      const siteSettings = container.lookup("site-settings:main");
      api.decorateCooked(highlightSyntax);
      api.decorateCooked(lightbox);
      if (siteSettings.support_mixed_text_direction) {
        api.decorateCooked(setTextDirections);
      }

      setupLazyLoading(api);

      api.decorateCooked($elem => {
        const players = $("audio", $elem);
        if (players.length) {
          players.on("play", () => {
            const postId = parseInt($elem.closest("article").data("post-id"));
            if (postId) {
              api.preventCloak(postId);
            }
          });
        }
      });
    });
  }
};
