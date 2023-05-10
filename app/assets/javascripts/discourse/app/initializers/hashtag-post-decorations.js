import { withPluginApi } from "discourse/lib/plugin-api";
import { replaceHashtagIconPlaceholder } from "discourse/lib/hashtag-autocomplete";

export default {
  name: "hashtag-post-decorations",
  after: "hashtag-css-generator",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const site = container.lookup("service:site");

    withPluginApi("0.8.7", (api) => {
      if (siteSettings.enable_experimental_hashtag_autocomplete) {
        api.decorateCookedElement(
          (post) => replaceHashtagIconPlaceholder(post, site),
          {
            onlyStream: true,
            id: "hashtag-icons",
          }
        );
      }
    });
  },
};
