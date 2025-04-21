import ArrayProxy from "@ember/array/proxy";
import { Promise } from "rsvp";
import discourseComputed from "discourse/lib/decorators";

export default class ResultSet extends ArrayProxy {
  loading = false;
  loadingMore = false;
  totalRows = 0;
  refreshing = false;
  content = null;
  loadMoreUrl = null;
  refreshUrl = null;
  findArgs = null;
  store = null;
  resultSetMeta = null;
  __type = null;

  @discourseComputed("totalRows", "length")
  canLoadMore(totalRows, length) {
    return length < totalRows;
  }

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
  }

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
}
