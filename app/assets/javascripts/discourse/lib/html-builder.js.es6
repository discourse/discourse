export function categoryLinkHTML(category, options) {
  var categoryOptions = {};
  if (options.hash) {
    if (options.hash.allowUncategorized) { categoryOptions.allowUncategorized = true; }
    if (options.hash.showParent) { categoryOptions.showParent = true; }
    if (options.hash.onlyStripe) { categoryOptions.onlyStripe = true; }
    if (options.hash.link !== undefined) { categoryOptions.link = options.hash.link; }
    if (options.hash.extraClasses) { categoryOptions.extraClasses = options.hash.extraClasses; }
    if (options.hash.categories) {
      categoryOptions.categories = Em.Handlebars.get(this, options.hash.categories, options);
    }
  }
  return new Handlebars.SafeString(Discourse.HTML.categoryBadge(category, categoryOptions));
}
