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

  show: function(post) {

    var currentUsername = this.get('username');
    this.setProperties({model: post, visible: true});

    // If we're showing the same user we showed last time, just keep it
    if (post.get('username') === currentUsername) { return; }

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


