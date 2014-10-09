/**
  Sets up the PageTracking hook.
**/
export default {
  name: "page-tracking",
  after: 'register-discourse-location',

  initialize: function() {
    var pageTracker = Discourse.PageTracker.current();
    pageTracker.start();
    var _ga_later = null;

    // Out of the box, Discourse tries to track google analytics
    // if it is present
    if (typeof window._gaq !== 'undefined') {
      pageTracker.on('change', function() {
         Em.run.cancel(_ga_later);
         _ga_later = Em.run.later(function(){
            _gaq.push(["_set", "title", Discourse.title]);
            window._gaq.push(['_trackPageview', window.location.pathname+window.location.search]);
            _ga_later = null;
        },350);
      });
      return;
    }

    // Also use Universal Analytics if it is present
    if (typeof window.ga !== 'undefined') {
      pageTracker.on('change', function() {
         Em.run.cancel(_ga_later.event);
          _ga_later = Em.run.later(function (){
            window.ga('send', 'pageview', {'page':window.location.pathname+window.location.search,'title':Discourse.title});
            _ga_later=null;
          },350);
      });
    }
  }
};
