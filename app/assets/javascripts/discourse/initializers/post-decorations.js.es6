import { decorateCooked } from 'discourse/lib/plugin-api';
import highlightSyntax from 'discourse/lib/highlight-syntax';
import lightbox from 'discourse/lib/lightbox';

export default {
  name: "post-decorations",
  initialize: function(container) {
    decorateCooked(container, highlightSyntax);
    decorateCooked(container, lightbox);
  }
};
