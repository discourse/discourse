import highlightSyntax from 'discourse/lib/highlight-syntax';
import lightbox from 'discourse/lib/lightbox';
import { getPluginApi } from 'discourse/lib/plugin-api';

export default {
  name: "post-decorations",
  initialize() {
    const api = getPluginApi('0.1');

    api.decorateCooked(highlightSyntax);
    api.decorateCooked(lightbox);
  }
};
