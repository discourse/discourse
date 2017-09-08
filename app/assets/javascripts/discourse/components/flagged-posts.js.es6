import FlaggedPost from 'admin/models/flagged-post';

export default Ember.Component.extend({
  canAct: Ember.computed.equal('filter', 'active'),
  showResolvedBy: Ember.computed.equal('filter', 'old'),
  allLoaded: false,

  actions: {
    removePost(flaggedPost) {
      this.get('flaggedPosts').removeObject(flaggedPost);
    },

    loadMore() {
      if (this.get('allLoaded')) {
        return;
      }

      const flaggedPosts = this.get('flaggedPosts');

      let args = {
        filter: this.get('query'),
        offset: flaggedPosts.length+1
      };

      let topic = this.get('topic');
      if (topic) {
        args.topic_id = topic.id;
      }

      return FlaggedPost.findAll(args).then(data => {
        if (data.length === 0) {
          this.set('allLoaded', true);
        }
        flaggedPosts.addObjects(data);
      });
    }
  }
});
