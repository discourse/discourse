import { categoryLinkHTML } from 'discourse/helpers/category-link';
import { registerUnbound } from 'discourse-common/lib/helpers';

registerUnbound('category-badge', function(cat, options) {
  options.link = false;
  return categoryLinkHTML(cat, options);
});
