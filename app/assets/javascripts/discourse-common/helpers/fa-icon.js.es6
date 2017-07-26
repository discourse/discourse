import { registerUnbound } from 'discourse-common/lib/helpers';
import { renderIcon } from 'discourse-common/lib/icon-library';

export function iconHTML(id, params) {
  return renderIcon('string', id, params);
}

registerUnbound('fa-icon', function(icon, params) {
  return new Handlebars.SafeString(iconHTML(icon, params));
});
