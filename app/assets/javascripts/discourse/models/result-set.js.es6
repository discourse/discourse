import computed from "ember-addons/ember-computed-decorators";

export default Ember.ArrayProxy.extend({
  loading: false,
  loadingMore: false,
  totalRows: 0,
  refreshing: false,

  content: null,
  loadMoreUrl: null,
  refreshUrl: null,
  findArgs: null,
  store: null,
  __type: null,
  resultSetMeta: null,

  @computed("totalRows", "length")
  canLoadMore(totalRows, length) {
    return length < totalRows;
  },

  loadMore() {
    const loadMoreUrl = this.get("loadMoreUrl");
    if (!loadMoreUrl) {
      return;
    }

    const totalRows = this.get("totalRows");
    if (this.get("length") < totalRows && !this.get("loadingMore")) {
      this.set("loadingMore", true);

      return this.store
        .appendResults(this, this.get("__type"), loadMoreUrl)
        .finally(() => this.set("loadingMore", false));
    }

    return Ember.RSVP.resolve();
  },

  refresh() {
    if (this.get("refreshing")) {
      return;
    }

    const refreshUrl = this.get("refreshUrl");
    if (!refreshUrl) {
      return;
    }

    this.set("refreshing", true);
    return this.store
      .refreshResults(this, this.get("__type"), refreshUrl)
      .finally(() => this.set("refreshing", false));
  }
});
