export default Ember.Controller.extend({
  queryParams: ['period', 'order', 'asc'],
  period: 'weekly',
  order: 'likes_received',
  asc: null,

  showTimeRead: Ember.computed.equal('period', 'all'),

  actions: {
    loadMore() {
      this.get('model').loadMore();
    }
  }
});
