export default Ember.Controller.extend({
  actions: {
    loadMore() {
      this.model.loadMore();
    }
  }
});
