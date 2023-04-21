import { withPluginApi } from "discourse/lib/plugin-api";
import { getHashtagTypeClasses } from "discourse/lib/hashtag-autocomplete";

export default {
  name: "hashtag-post-decorations",
  after: "hashtag-css-generator",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const site = container.lookup("service:site");

    withPluginApi("0.8.7", (api) => {
      if (siteSettings.enable_experimental_hashtag_autocomplete) {
        api.decorateCookedElement(
          (post) => {
            const iconElWrapper = document.createElement("div");

            post.querySelectorAll(".hashtag-cooked").forEach((hashtagEl) => {
              const iconPlaceholderEl = hashtagEl.querySelector(
                ".hashtag-icon-placeholder"
              );
              const hashtagType = hashtagEl.dataset.type;
              const hashtagTypeClass = getHashtagTypeClasses()[hashtagType];
              if (iconPlaceholderEl && hashtagTypeClass) {
                iconElWrapper.innerHTML = hashtagTypeClass
                  .generateIconHTML({
                    icon: site.hashtag_icons[hashtagType],
                    id: hashtagEl.dataset.id,
                  })
                  .trim();
                iconPlaceholderEl.replaceWith(iconElWrapper.firstChild);
                iconElWrapper.innerHTML = "";
              }
            });
          },
          {
            onlyStream: true,
            id: "hashtag-icons",
          }
        );
      }
    });
  },
};
