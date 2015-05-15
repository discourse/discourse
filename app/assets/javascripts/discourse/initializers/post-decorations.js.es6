import { decorateCooked } from 'discourse/lib/plugin-api';
import HighlightSyntax from 'discourse/lib/highlight-syntax';
import Lightbox from 'discourse/lib/lightbox';

export default {
  name: "post-decorations",
  initialize: function(container) {
    decorateCooked(container, HighlightSyntax);
    decorateCooked(container, Lightbox);
  }
};
