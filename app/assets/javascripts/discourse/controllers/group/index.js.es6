/**
  Handles displaying posts within a group

  @class GroupIndexController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
export default Ember.ArrayController.extend({
  needs: ['group'],
  loading: false,

  actions: {
    loadMore: function() {

      if (this.get('loading')) { return; }
      this.set('loading', true);
      var posts = this.get('model'),
          self = this;
      if (posts && posts.length) {
        var lastPostId = posts[posts.length-1].get('id'),
            group = this.get('controllers.group.model');

        group.findPosts({beforePostId: lastPostId}).then(function(newPosts) {
          posts.addObjects(newPosts);
          self.set('loading', false);
        });
      }
    }
  }
});

