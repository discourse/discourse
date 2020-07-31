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
      api.decorateCooked(
        elem => {
          return highlightSyntax(elem, siteSettings);
        },
        {
          id: "discourse-syntax-highlighting"
        }
      );

      api.decorateCookedElement(
        elem => {
          return lightbox(elem, siteSettings);
        },
        { id: "discourse-lightbox" }
      );
      api.decorateCookedElement(lightbox, { id: "discourse-lightbox" });
      if (siteSettings.support_mixed_text_direction) {
        api.decorateCooked(setTextDirections, {
          id: "discourse-text-direction"
        });
      }

      setupLazyLoading(api);

      api.decorateCooked(
        $elem => {
          const players = $("audio", $elem);
          if (players.length) {
            players.on("play", () => {
              const postId = parseInt(
                $elem.closest("article").data("post-id"),
                10
              );
              if (postId) {
                api.preventCloak(postId);
              }
            });
          }
        },
        { id: "discourse-audio" }
      );

      const caps = container.lookup("capabilities:main");
      if (caps.isSafari || caps.isIOS) {
        api.decorateCookedElement(
          elem => {
            const video = elem.querySelector("video");
            if (video && !video.poster) {
              const source = video.querySelector("source");
              if (source) {
                // this tricks Safari into loading the video preview
                source.parentElement.load();
              }
            }
          },
          { id: "safari-video-poster", afterAdopt: true, onlyStream: true }
        );
      }
    });
  }
};
