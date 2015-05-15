export default Ember.ArrayProxy.extend({
  loading: false,
  loadingMore: false,
  totalRows: 0,
  refreshing: false,

  canLoadMore: function() {
    return this.get('length') < this.get('totalRows');
  }.property('totalRows', 'length'),

  loadMore() {
    const loadMoreUrl = this.get('loadMoreUrl');
    if (!loadMoreUrl) { return; }

    const totalRows = this.get('totalRows');
    if (this.get('length') < totalRows && !this.get('loadingMore')) {
      this.set('loadingMore', true);

      const self = this;
      return this.store.appendResults(this, this.get('__type'), loadMoreUrl).finally(function() {
        self.set('loadingMore', false);
      });
    }

    return Ember.RSVP.resolve();
  },

  refresh() {
    if (this.get('refreshing')) { return; }

    const refreshUrl = this.get('refreshUrl');
    if (!refreshUrl) { return; }

    const self = this;
    this.set('refreshing', true);
    return this.store.refreshResults(this, this.get('__type'), refreshUrl).finally(function() {
      self.set('refreshing', false);
    });

  }
});
