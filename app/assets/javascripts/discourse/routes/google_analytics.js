/*global _gaq:true */

(function() {

  Ember.Route.reopen({
    setup: function(router, context) {
      var path;
      this._super(router, context);
      if (window._gaq) {
        if (this.get("isLeafRoute")) {
          /* first hit is tracked inline
          */

          if (router.afterFirstHit) {
            path = this.absoluteRoute(router);
            _gaq.push(['_trackPageview', path]);
          } else {
            router.afterFirstHit = true;
          }
          return null;
        }
      }
    }
  });

}).call(this);
