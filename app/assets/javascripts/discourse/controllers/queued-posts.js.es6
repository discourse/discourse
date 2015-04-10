export default Ember.Controller.extend({

  actions: {
    approve(post) {
      post.update({ state: 'approved' }).then(() => {
        this.get('model').removeObject(post);
      });
    },

    reject(post) {
      post.update({ state: 'rejected' }).then(() => {
        this.get('model').removeObject(post);
      });
    }
  }
});
