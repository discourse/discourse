import { withPluginApi } from "discourse/lib/plugin-api";
import getVideoAttributes from "../lib/lazy-video-attributes";
import { hbs } from "ember-cli-htmlbars";

function initLazyEmbed(api) {
  api.decorateCookedElement(
    (cooked, helper) => {
      if (cooked.classList.contains("d-editor-preview")) {
        return;
      }

      const lazyContainers = cooked.querySelectorAll(".lazy-video-container");

      lazyContainers.forEach((container) => {
        const siteSettings = api.container.lookup("site-settings:main");
        const videoAttributes = getVideoAttributes(container);

        if (siteSettings[`lazy_${videoAttributes.providerName}_enabled`]) {
          const onLoadedVideo = () => {
            const postId = cooked.closest("article")?.dataset?.postId;
            if (postId) {
              api.preventCloak(parseInt(postId, 10));
            }
          };

          const lazyVideo = helper.renderGlimmer(
            "p.lazy-video-wrapper",
            hbs`<LazyVideo @videoAttributes={{@data.param}} @onLoadedVideo={{@data.onLoadedVideo}}/>`,
            { param: videoAttributes, onLoadedVideo }
          );

          container.replaceWith(lazyVideo);
        }
      });
    },
    { onlyStream: true, id: "discourse-lazy-videos" }
  );
}

export default {
  name: "discourse-lazy-videos",

  initialize() {
    withPluginApi("1.6.0", initLazyEmbed);
  },
};
