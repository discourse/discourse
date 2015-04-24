export default Ember.Controller.extend({
  queryParams: ['period', 'order', 'asc', 'name'],
  period: 'weekly',
  order: 'likes_received',
  asc: null,
  name: '',

  showTimeRead: Ember.computed.equal('period', 'all'),

  _setName: Discourse.debounce(function() {
    this.set('name', this.get('nameInput'));
  }, 500).observes('nameInput'),

  actions: {
    loadMore() {
      this.get('model').loadMore();
    }
  }
});
