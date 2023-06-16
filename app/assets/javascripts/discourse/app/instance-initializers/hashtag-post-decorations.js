import { withPluginApi } from "discourse/lib/plugin-api";
import { replaceHashtagIconPlaceholder } from "discourse/lib/hashtag-autocomplete";

export default {
  after: "hashtag-css-generator",

  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");
    const site = owner.lookup("service:site");

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
