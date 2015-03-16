export default Ember.ArrayProxy.extend({
  loading: false,
  loadingMore: false,
  totalRows: 0,

  loadMore() {
    const loadMoreUrl = this.get('loadMoreUrl');
    if (!loadMoreUrl) { return; }

    const totalRows = this.get('totalRows');
    if (this.get('length') < totalRows && !this.get('loadingMore')) {
      this.set('loadingMore', true);

      const self = this;
      return this.store.appendResults(this, this.get('__type'), loadMoreUrl).then(function() {
        self.set('loadingMore', false);
      });
    }

    return Ember.RSVP.resolve();
  }
});
