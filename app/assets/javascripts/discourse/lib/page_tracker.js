/**
  Called whenever the "page" changes. This allows us to set up analytics 
  and other tracking.

  To get notified when the page changes, you can install a hook like so:

  ```javascript
    Discourse.PageTracker.current().on('change', function(url) {
      console.log('the page changed to: ' + url);
    });
  ```

  @class PageTracker
  @namespace Discourse
  @module Discourse
**/
Discourse.PageTracker = Ember.Object.extend(Ember.Evented, {
  start: function() {
    if (this.get('started')) { return; }

    var router = Discourse.__container__.lookup('router:main'),
        self = this;

    router.on('didTransition', function() {
      var router = this;
      self.trigger('change', router.get('url'));
    });
    this.set('started', true);
  }
});
Discourse.PageTracker.reopenClass(Discourse.Singleton);
