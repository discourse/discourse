import loadScript from 'discourse/lib/load-script';
import DiscourseRoute from 'discourse/routes/discourse';

export default DiscourseRoute.extend({

  // this route requires the sanitizer
  beforeModel() {
    loadScript('defer/html-sanitizer-bundle');
  },

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
