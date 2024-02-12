import { getHashtagTypeClasses } from "discourse/lib/hashtag-type-registry";

export default {
  after: "category-color-css-generator",

  /**
   * This generates CSS classes for each hashtag type,
   * which are used to color the hashtag icons in the composer,
   * cooked posts, and the sidebar.
   *
   * Each type has its own corresponding class, which is registered
   * with the hashtag type via api.registerHashtagType. The default
   * ones in core are CategoryHashtagType and TagHashtagType.
   */
  initialize(owner) {
    this.site = owner.lookup("service:site");

    const cssTag = document.createElement("style");
    cssTag.type = "text/css";
    cssTag.id = "hashtag-css-generator";
    cssTag.innerHTML = Object.values(getHashtagTypeClasses())
      .map((hashtagType) => hashtagType.generatePreloadedCssClasses())
      .flat()
      .join("\n");
    document.head.appendChild(cssTag);
  },
};
