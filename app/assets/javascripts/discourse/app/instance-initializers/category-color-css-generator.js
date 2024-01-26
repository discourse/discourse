export function generateCategoriesCss(categories) {
  if (!categories?.length) {
    return "";
  }

  // Define color variables
  const css = [
    ":root {",
    ...categories.map(
      (category) => `--category-${category.id}-color: #${category.color};`
    ),
    "}",
  ];

  // Define classes for badges
  categories.forEach((category) => {
    css.push(`.badge-category[data-category-id="${category.id}"] {`);
    css.push(`--category-badge-color: var(--category-${category.id}-color);`);
    css.push(`--category-badge-text-color: #${category.text_color};`);
    if (category.parentCategory) {
      css.push(
        `--parent-category-badge-color: var(--category-${category.parentCategory.id}-color);`
      );
    }
    css.push(`}`);
  });

  css.push("");

  return css.join("\n");
}

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

    const cssTag = document.createElement("style");
    cssTag.type = "text/css";
    cssTag.id = "category-colors";
    cssTag.innerHTML = generateCategoriesCss(this.site.categories);

    document.head.appendChild(cssTag);
  },
};
