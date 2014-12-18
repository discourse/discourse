import { categoryLinkHTML } from 'discourse/helpers/category-badge';
import registerUnbound from 'discourse/helpers/register-unbound';

registerUnbound('category-badge', function(cat, options) {
  options.link = false;
  return categoryLinkHTML(cat, options);
});
