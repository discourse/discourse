import { categoryLinkHTML } from 'discourse/lib/html-builder';

Handlebars.registerHelper('category-link-raw', function(property, options) {
  return categoryLinkHTML(property, options);
});
