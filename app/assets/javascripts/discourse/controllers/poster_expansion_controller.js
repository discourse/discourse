/**
  A controller for expanding information about a poster.

  @class PosterExpansion
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.PosterExpansionController = Discourse.ObjectController.extend({
  needs: ['topic'],
  visible: false,
  user: null,
  participant: null,

  postStream: Em.computed.alias('controllers.topic.postStream'),
  enoughPostsForFiltering: Em.computed.gte('participant.post_count', 2),

  showFilter: Em.computed.and('postStream.hasNoFilters', 'enoughPostsForFiltering'),
  showName: Discourse.computed.propertyNotEqual('user.name', 'user.username'),

  hasUserFilters: Em.computed.gt('postStream.userFilters.length', 0),

  show: function(post) {

    // Don't show on mobile
    if (Discourse.Mobile.mobileView) {
      Discourse.URL.routeTo(post.get('usernameUrl'));
      return;
    }

    var currentPostId = this.get('id'),
        wasVisible = this.get('visible');

    this.setProperties({model: post, visible: true});

    // If we click the avatar again, close it.
    if (post.get('id') === currentPostId && wasVisible) {
      this.setProperties({ visible: false, model: null });
      return;
    }

    this.set('participant', null);

    // Retrieve their participants info
    var participants = this.get('topic.details.participants');
    if (participants) {
      this.set('participant', participants.findBy('username', post.get('username')));
    }

    var self = this;
    self.set('user', null);
    Discourse.User.findByUsername(post.get('username')).then(function (user) {
      self.set('user', user);
    });
  },

  close: function() {
    this.set('visible', false);
  },

  actions: {
    togglePosts: function(user) {
      var postStream = this.get('controllers.topic.postStream');
      postStream.toggleParticipant(user.get('username'));
      this.close();
    },

    cancelFilter: function() {
      this.get('postStream').cancelFilter();
      this.close();
    }
  }

});


