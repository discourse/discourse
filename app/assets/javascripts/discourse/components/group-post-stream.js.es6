export default Ember.Component.extend({
  actions: {
    // TODO: When on Ember 1.13, use a closure action
    loadMore() {
      this.sendAction('loadMore');
    }
  }
});
