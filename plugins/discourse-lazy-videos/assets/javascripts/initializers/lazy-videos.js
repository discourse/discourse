import { withPluginApi } from "discourse/lib/plugin-api";

function initLazyEmbed(api) {
  const lazyVideos = api.container.lookup("service:lazy-videos");

  api.decorateCookedElement(
    (cooked) => {
      if (cooked.classList.contains("d-editor-preview")) {
        return;
      }
      lazyVideos.decorateLazyContainers(cooked, api);
    },
    { id: "discourse-lazy-videos" }
  );
}

export default {
  name: "discourse-lazy-videos",

  initialize() {
    withPluginApi("1.5.0", initLazyEmbed);
  },
};
