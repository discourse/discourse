import { registerUnbound } from 'discourse-common/lib/helpers';
import renderUnboundPreview from '../lib/render-preview';
import buttonHTML from '../lib/list-button';

registerUnbound('preview-unbound', function(thumbnails, params) {
  return new Handlebars.SafeString(renderUnboundPreview(thumbnails, params));
});

registerUnbound('list-button', function(button, params) {
  return new Handlebars.SafeString(buttonHTML(button, params));
});
