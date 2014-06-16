/**
  This view handles rendering of a user's stream

  @class UserStreamView
  @extends Discourse.View
  @namespace Discourse
  @uses Discourse.LoadMore
  @module Discourse
**/
Discourse.UserStreamView = Discourse.View.extend(Discourse.LoadMore, {
  loading: false,
  eyelineSelector: '.user-stream .item',
  classNames: ['user-stream'],

  actions: {
    loadMore: function() {
      var self = this;
      if (this.get('loading')) { return; }

      var stream = this.get('controller.model');
      stream.findItems().then(function() {
        self.set('loading', false);
        self.get('eyeline').flushRest();
      }).catch(function() {
        // If we were already loading...
      });
    }
  }
});
