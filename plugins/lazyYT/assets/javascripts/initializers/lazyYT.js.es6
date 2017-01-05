import { withPluginApi } from 'discourse/lib/plugin-api';

const returnFalse = () => false;

export default {
  name: "apply-lazyYT",
  initialize() {
    withPluginApi('0.1', api => {
      api.decorateCooked($elem => {

        const iframes = $('.lazyYT', $elem);
        if (iframes.length === 0) { return; }

        $('.lazyYT', $elem).lazyYT({
          onPlay(e, $el) {
            // don't cloak posts that have playing videos in them
            const postId = parseInt($el.closest('article').data('post-id'));
            if (postId) {
              api.preventCloak(postId);
            }

            // We use this because watching videos fullscreen in Chrome was super buggy
            // otherwise. Thanks to arrendek from q23 for the technique.
            $('iframe', iframes).iframeTracker({ blurCallback: () => {
              $(document).on("scroll.discourse-youtube", returnFalse);
              window.setTimeout(() => $(document).off('scroll.discourse-youtube', returnFalse), 1500);
              $(document).scroll();
            }});
          }
        });

      });
    });
  }
};
