import discourseComputed from "discourse-common/utils/decorators";
import { Promise } from "rsvp";

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

  @discourseComputed("totalRows", "length")
  canLoadMore(totalRows, length) {
    return length < totalRows;
  },

  loadMore() {
    const loadMoreUrl = this.loadMoreUrl;
    if (!loadMoreUrl) {
      return;
    }

    const totalRows = this.totalRows;
    if (this.length < totalRows && !this.loadingMore) {
      this.set("loadingMore", true);

      return this.store
        .appendResults(this, this.__type, loadMoreUrl)
        .finally(() => this.set("loadingMore", false));
    }

    return Promise.resolve();
  },

  refresh() {
    if (this.refreshing) {
      return;
    }

    const refreshUrl = this.refreshUrl;
    if (!refreshUrl) {
      return;
    }

    this.set("refreshing", true);
    return this.store
      .refreshResults(this, this.__type, refreshUrl)
      .finally(() => this.set("refreshing", false));
  }
});
