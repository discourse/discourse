export function categoryLinkHTML(category, options) {
  var categoryOptions = {};

  // TODO: This is a compatibility layer with the old helper structure.
  // Can be removed once we migrate to `registerUnbound` fully
  if (options && options.hash) { options = options.hash; }

  if (options) {
    if (options.allowUncategorized) { categoryOptions.allowUncategorized = true; }
    if (options.showParent) { categoryOptions.showParent = true; }
    if (options.onlyStripe) { categoryOptions.onlyStripe = true; }
    if (options.link !== undefined) { categoryOptions.link = options.link; }
    if (options.extraClasses) { categoryOptions.extraClasses = options.extraClasses; }
  }
  return new Handlebars.SafeString(Discourse.HTML.categoryBadge(category, categoryOptions));
}
