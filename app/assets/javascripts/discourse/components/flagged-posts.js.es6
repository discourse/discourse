import FlaggedPost from 'admin/models/flagged-post';

export default Ember.Component.extend({
  canAct: Ember.computed.equal('filter', 'active'),
  showResolvedBy: Ember.computed.equal('filter', 'old'),

  actions: {
    removePost(flaggedPost) {
      this.get('flaggedPosts').removeObject(flaggedPost);
    },

    loadMore() {
      const flaggedPosts = this.get('flaggedPosts');
      return FlaggedPost.findAll({
        filter: this.get('query'),
        offset: flaggedPosts.length+1
      }).then(data => {
        if (data.length===0) {
          flaggedPosts.set("allLoaded",true);
        }
        flaggedPosts.addObjects(data);
      });
    },

  }
});
