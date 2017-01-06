import highlightSyntax from 'discourse/lib/highlight-syntax';
import lightbox from 'discourse/lib/lightbox';
import { withPluginApi } from 'discourse/lib/plugin-api';

export default {
  name: "post-decorations",
  initialize() {
    withPluginApi('0.1', api => {
      api.decorateCooked(highlightSyntax);
      api.decorateCooked(lightbox);

      api.decorateCooked($elem => {
        const players = $('audio', $elem);
        if (players.length) {
          players.on('play', () => {
            const postId = parseInt($elem.closest('article').data('post-id'));
            if (postId) {
              api.preventCloak(postId);
            }
          });
        }
      });
    });
  }
};
