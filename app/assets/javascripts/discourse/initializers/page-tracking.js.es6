import { cleanDOM } from 'discourse/lib/clean-dom';
import { startPageTracking, onPageChange } from 'discourse/lib/page-tracker';
import { viewTrackingRequired } from 'discourse/lib/ajax';

export default {
  name: "page-tracking",

  initialize(container) {

    // Tell our AJAX system to track a page transition
    const router = container.lookup('router:main');
    router.on('willTransition', viewTrackingRequired);
    router.on('didTransition', cleanDOM);

    startPageTracking(router);

    // Out of the box, Discourse tries to track google analytics
    // if it is present
    if (typeof window._gaq !== 'undefined') {
      onPageChange((url, title) => {
        window._gaq.push(["_set", "title", title]);
        window._gaq.push(['_trackPageview', url]);
      });
      return;
    }

    // Also use Universal Analytics if it is present
    if (typeof window.ga !== 'undefined') {
      onPageChange((url, title) => {
        window.ga('send', 'pageview', {page: url, title: title});
      });
    }

    // And Google Tag Manager too
    if (typeof window.dataLayer !== 'undefined') {
      onPageChange((url, title) => {
        window.dataLayer.push({
          'event': 'virtualPageView',
          'page': {
            'title': title,
            'url': url
          }
        });
      });
    }
  }
};
