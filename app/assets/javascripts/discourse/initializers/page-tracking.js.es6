import { cleanDOM } from 'discourse/routes/discourse';

export default {
  name: "page-tracking",
  after: 'register-discourse-location',

  initialize: function(container) {

    // Tell our AJAX system to track a page transition
    var router = container.lookup('router:main');
    router.on('willTransition', function() {
      Discourse.viewTrackingRequired();
    });

    router.on('didTransition', function() {
      Em.run.scheduleOnce('afterRender', Ember.Route, cleanDOM);
    });

    var pageTracker = Discourse.PageTracker.current();
    pageTracker.start();

    // Out of the box, Discourse tries to track google analytics
    // if it is present
    if (typeof window._gaq !== 'undefined') {
      pageTracker.on('change', function(url, title) {
        window._gaq.push(["_set", "title", title]);
        window._gaq.push(['_trackPageview', url]);
      });
      return;
    }

    // Also use Universal Analytics if it is present
    if (typeof window.ga !== 'undefined') {
      pageTracker.on('change', function(url, title) {
        window.ga('send', 'pageview', {page: url, title: title});
      });
    }
  }
};
