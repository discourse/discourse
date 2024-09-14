import { getHashtagTypeClasses } from "discourse/lib/hashtag-type-registry";

export default {
  after: "register-hashtag-types",

  /**
   * This generates CSS classes for each hashtag type,
   * which are used to color the hashtag icons in the composer,
   * cooked posts, and the sidebar.
   *
   * Each type has its own corresponding class, which is registered
   * with the hashtag type via api.registerHashtagType. The default
   * ones in core are CategoryHashtagType and TagHashtagType.
   */
  initialize() {
    const cssTag = document.createElement("style");
    cssTag.id = "hashtag-css-generator";
    cssTag.innerHTML = Object.values(getHashtagTypeClasses())
      .map((hashtagType) => hashtagType.generatePreloadedCssClasses())
      .flat()
      .join("\n");
    document.head.appendChild(cssTag);
  },
};
