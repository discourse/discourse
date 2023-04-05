export default {
  name: "category-color-css-generator",
  after: "register-hashtag-types",

  /**
   * This generates CSS variables for each category color,
   * which can be used in themes to style category-specific elements.
   *
   * It is also used when styling hashtag icons, since they are colored
   * based on the category color.
   */
  initialize(container) {
    const site = container.lookup("service:site");

    const generatedCssVariables = [
      ":root {",
      ...(site.categories || []).map(
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
