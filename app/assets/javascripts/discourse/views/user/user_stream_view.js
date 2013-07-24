/**
  This view handles rendering of a user's stream

  @class UserStreamView
  @extends Discourse.View
  @namespace Discourse
  @uses Discourse.LoadMore
  @module Discourse
**/
Discourse.UserStreamView = Ember.CollectionView.extend(Discourse.LoadMore, {
  loading: false,
  content: Em.computed.alias('controller.model.content'),
  eyelineSelector: '#user-activity .user-stream .item',
  classNames: ['user-stream'],

  itemViewClass: Ember.View.extend({
    templateName: 'user/stream_item',
    init: function() {
      this._super();
      this.set('context', this.get('content'));
    }
  }),

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


Discourse.View.registerHelper('userStream', Discourse.UserStreamView);