import { withPluginApi } from "discourse/lib/plugin-api";
import LazyVideo from "../discourse/components/lazy-video";
import getVideoAttributes from "../lib/lazy-video-attributes";

function initLazyEmbed(api) {
  api.decorateCookedElement(
    (cooked, helper) => {
      if (cooked.classList.contains("d-editor-preview")) {
        return;
      }

      const lazyContainers = cooked.querySelectorAll(".lazy-video-container");

      lazyContainers.forEach((container) => {
        const siteSettings = api.container.lookup("service:site-settings");
        const videoAttributes = getVideoAttributes(container);

        if (siteSettings[`lazy_${videoAttributes.providerName}_enabled`]) {
          const onLoadedVideo = () => {
            const postId = cooked.closest("article")?.dataset?.postId;
            if (postId) {
              api.preventCloak(parseInt(postId, 10));
            }
          };

          const lazyVideo = document.createElement("p");
          lazyVideo.classList.add("lazy-video-wrapper");

          helper.renderGlimmer(
            lazyVideo,
            <template>
              <LazyVideo
                @videoAttributes={{@data.param}}
                @onLoadedVideo={{@data.onLoadedVideo}}
              />
            </template>,
            { param: videoAttributes, onLoadedVideo }
          );

          container.replaceWith(lazyVideo);
        }
      });
    },
    { onlyStream: true }
  );
}

export default {
  name: "discourse-lazy-videos",

  initialize() {
    withPluginApi(initLazyEmbed);
  },
};
