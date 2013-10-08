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

  enoughPostsForFiltering: Em.computed.gte('participant.post_count', 2),
  showFilter: Em.computed.and('controllers.topic.postStream.hasNoFilters', 'enoughPostsForFiltering'),
  showName: Discourse.computed.propertyNotEqual('user.name', 'user.username'),

  show: function(post) {

    // Don't show on mobile
    if (Discourse.Mobile.mobileView) {
      Discourse.URL.routeTo(post.get('usernameUrl'));
      return;
    }

    var currentUsername = this.get('username');
    this.setProperties({model: post, visible: true});

    // If we're showing the same user we showed last time, just keep it
    if (post.get('username') === currentUsername) { return; }

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
    }
  }

});


