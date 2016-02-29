import { withPluginApi } from 'discourse/lib/plugin-api';

export default {
  name: "apply-lazyYT",
  initialize() {
    withPluginApi('0.1', api => {
      api.decorateCooked($elem => $('.lazyYT', $elem).lazyYT({
        onPlay(e, $el) {
          // don't cloak posts that have playing videos in them
          const postId = parseInt($el.closest('article').data('post-id'));
          if (postId) {
            api.preventCloak(postId);
          }
        }
      }));
    });
  }
};
