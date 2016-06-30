import { cleanDOM } from 'discourse/routes/discourse';
import { startPageTracking, onPageChange } from 'discourse/lib/page-tracker';
import { viewTrackingRequired } from 'discourse/lib/ajax';

export default {
  name: "page-tracking",

  initialize(container) {

    const cache = {};
    var transitionCount = 0;

    // Tell our AJAX system to track a page transition
    const router = container.lookup('router:main');
    router.on('willTransition', viewTrackingRequired);

    router.on('didTransition', function() {
      Em.run.scheduleOnce('afterRender', Ember.Route, cleanDOM);
      transitionCount++;
      _.each(cache, (v,k) => {
        if (v && v.target && v.target < transitionCount) {
           delete cache[k];
        }
      });
    });

    router.transientCache = function(key, data, count) {
      if (data === undefined) {
        return cache[key];
      } else {
        return cache[key] = {data, target: transitionCount + count};
      }
    };

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
  }
};
