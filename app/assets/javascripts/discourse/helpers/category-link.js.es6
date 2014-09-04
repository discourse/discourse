import { categoryLinkHTML } from 'discourse/lib/html-builder';

export default Handlebars.registerHelper('category-link', function(property, options) {
  return categoryLinkHTML(Ember.Handlebars.get(this, property, options), options);
});
