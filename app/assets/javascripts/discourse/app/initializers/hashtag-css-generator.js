import { withPluginApi } from "discourse/lib/plugin-api";
import { getHashtagTypeClasses } from "discourse/lib/hashtag-autocomplete";

export default {
  name: "hashtag-css-generator",
  after: "category-color-css-generator",

  /**
   * This generates CSS classes for each hashtag type,
   * which are used to color the hashtag icons in the composer,
   * cooked posts, and the sidebar.
   *
   * Each type has its own corresponding class, which is registered
   * with the hastag type via api.registerHashtagType. The default
   * ones in core are CategoryHashtagType and TagHashtagType.
   */
  initialize(container) {
    withPluginApi("0.8.7", () => {
      let generatedCssClasses = [];

      Object.values(getHashtagTypeClasses()).forEach((hashtagTypeClass) => {
        const hashtagType = new hashtagTypeClass(container);
        hashtagType.preloadedData.forEach((model) => {
          generatedCssClasses = generatedCssClasses.concat(
            hashtagType.generateColorCssClasses(model)
          );
        });
      });

      const cssTag = document.createElement("style");
      cssTag.type = "text/css";
      cssTag.id = "hashtag-css-generator";
      cssTag.innerHTML = generatedCssClasses.join("\n");
      document.head.appendChild(cssTag);
    });
  },
};
