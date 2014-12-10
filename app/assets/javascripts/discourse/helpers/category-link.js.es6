import { categoryLinkHTML } from 'discourse/lib/html-builder';
import registerUnbound from 'discourse/helpers/register-unbound';

registerUnbound('category-link', categoryLinkHTML);
