export default Ember.Controller.extend({
  queryParams: ['order', 'asc'],
  order: 'likes_received',
  asc: null,

  showTimeRead: Ember.computed.equal('period', 'all'),

  actions: {
    loadMore() {
      this.get('model').loadMore();
    }
  }
});
