import DiscourseRoute from 'discourse/routes/discourse';

export default DiscourseRoute.extend({

  model() {
    return this.store.find('queuedPost', {status: 'new'});
  },

  actions: {
    removePost(post) {
      this.modelFor('queued-posts').removeObject(post);
    },

    refresh() {
      this.modelFor('queued-posts').refresh();
    }
  }
});
