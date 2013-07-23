/**
  This view handles rendering of a user's stream

  @class UserStreamView
  @extends Discourse.View
  @namespace Discourse
  @uses Discourse.Scrolling
  @module Discourse
**/
Discourse.UserStreamView = Discourse.View.extend(Discourse.Scrolling, {
  templateName: 'user/stream',
  loading: false,
  elementId: 'user-stream',

  scrolled: function(e) {
    var eyeline = this.get('eyeline');
    if (eyeline) { eyeline.update(); }
  },

  loadMore: function() {
    var userStreamView = this;
    if (userStreamView.get('loading')) { return; }

    var stream = this.get('stream');
    stream.findItems().then(function() {
      userStreamView.set('loading', false);
      userStreamView.get('eyeline').flushRest();
    });
  },

  willDestroyElement: function() {
    this.unbindScrolling();
  },

  didInsertElement: function() {
    this.bindScrolling();

    var eyeline = new Discourse.Eyeline('#user-stream .item');
    this.set('eyeline', eyeline);

    var userStreamView = this;
    eyeline.on('sawBottom', function() {
      userStreamView.loadMore();
    });
  }
});


Discourse.View.registerHelper('userStream', Discourse.UserStreamView);