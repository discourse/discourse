import highlightSyntax from 'discourse/lib/highlight-syntax';
import lightbox from 'discourse/lib/lightbox';
import { withPluginApi } from 'discourse/lib/plugin-api';

export default {
  name: "post-decorations",
  initialize() {
    withPluginApi('0.1', api => {
      api.decorateCooked(highlightSyntax);
      api.decorateCooked(lightbox);
    });
  }
};
