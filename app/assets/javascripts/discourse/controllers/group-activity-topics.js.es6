export default Ember.Controller.extend({
  actions: {
    loadMore() {
      this.get("model").loadMore();
    }
  }
});
