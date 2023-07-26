export default {
  after: "register-hashtag-types",

  /**
   * This generates CSS variables for each category color,
   * which can be used in themes to style category-specific elements.
   *
   * It is also used when styling hashtag icons, since they are colored
   * based on the category color.
   */
  initialize(owner) {
    this.site = owner.lookup("service:site");

    // If the site is login_required and the user is anon there will be no categories preloaded.
    if (!this.site.categories) {
      return;
    }

    const generatedCssVariables = [
      ":root {",
      ...this.site.categories.map(
        (category) => `--category-${category.id}-color: #${category.color};`
      ),
      "}",
    ];

    const cssTag = document.createElement("style");
    cssTag.type = "text/css";
    cssTag.id = "category-color-css-generator";
    cssTag.innerHTML = generatedCssVariables.join("\n");
    document.head.appendChild(cssTag);
  },
};
