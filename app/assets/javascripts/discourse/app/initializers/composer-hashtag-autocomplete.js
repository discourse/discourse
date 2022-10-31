import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "composer-hashtag-autocomplete",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    withPluginApi("1.4.0", (api) => {
      if (siteSettings.enable_experimental_hashtag_autocomplete) {
        api.registerHashtagSearchParam("category", "topic-composer", 100);
        api.registerHashtagSearchParam("tag", "topic-composer", 50);
      }
    });
  },
};
