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

  loadMore: function() {
    var userStreamView = this;
    if (userStreamView.get('loading')) { return; }

    var stream = this.get('controller.model');
    stream.findItems().then(function() {
      userStreamView.set('loading', false);
      userStreamView.get('eyeline').flushRest();
    });
  }
});
