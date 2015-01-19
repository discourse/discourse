import { categoryLinkHTML } from 'discourse/helpers/category-link';
import registerUnbound from 'discourse/helpers/register-unbound';

registerUnbound('category-badge', function(cat, options) {
  options.link = false;
  return categoryLinkHTML(cat, options);
});
