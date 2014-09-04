import { categoryLinkHTML } from 'discourse/lib/html-builder';

Handlebars.registerHelper('category-badge', function(property, options) {
  options.hash.link = false;
  return categoryLinkHTML(Ember.Handlebars.get(this, property, options), options);
});
