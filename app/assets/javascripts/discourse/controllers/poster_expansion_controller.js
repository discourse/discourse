/**
  A controller for expanding information about a poster.

  @class PosterExpansion
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.PosterExpansionController = Discourse.ObjectController.extend({
  needs: ['topic'],

  show: function(user, post) {
    this.setProperties({model: user, post: post});
  },

  close: function() {
    this.set('model', null);
  },

  actions: {
    togglePosts: function(user) {
      var postStream = this.get('controllers.topic.postStream');
      postStream.toggleParticipant(user.get('username'));
      this.close();
    }
  }

});


