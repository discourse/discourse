import { fmt } from 'discourse/lib/computed';

export default Ember.ArrayController.extend({
  needs: ['group'],
  loading: false,
  emptyText: fmt('type', 'groups.empty.%@'),

  actions: {
    loadMore() {

      if (this.get('loading')) { return; }
      this.set('loading', true);
      const posts = this.get('model');
      if (posts && posts.length) {
        const beforePostId = posts[posts.length-1].get('id');
        const group = this.get('controllers.group.model');

        const opts = { beforePostId, type: this.get('type') };
        group.findPosts(opts).then(newPosts => {
          posts.addObjects(newPosts);
          this.set('loading', false);
        });
      }
    }
  }
});

