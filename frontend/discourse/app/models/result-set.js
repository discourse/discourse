import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import LegacyArrayLikeObject from "discourse/lib/legacy-array-like-object";

export default class ResultSet extends LegacyArrayLikeObject {
  @tracked extras;
  @tracked findArgs;
  @tracked loadMoreUrl = null;
  @tracked loading = false;
  @tracked loadingMore = false;
  @tracked refreshUrl = null;
  @tracked refreshing = false;
  @tracked resultSetMeta;
  @tracked totalRows = 0;
  store = null;
  __type;

  @dependentKeyCompat
  get canLoadMore() {
    return this.content.length < this.totalRows;
  }

  @action
  async loadMore() {
    const loadMoreUrl = this.loadMoreUrl;
    if (!loadMoreUrl) {
      return;
    }

    const totalRows = this.totalRows;
    if (this.content.length < totalRows && !this.loadingMore) {
      this.loadingMore = true;

      try {
        return await this.store.appendResults(this, this.__type, loadMoreUrl);
      } finally {
        this.loadingMore = false;
      }
    }
  }

  @action
  async refresh() {
    if (this.refreshing) {
      return;
    }

    const refreshUrl = this.refreshUrl;
    if (!refreshUrl) {
      return;
    }

    this.refreshing = true;
    try {
      return await this.store.refreshResults(this, this.__type, refreshUrl);
    } finally {
      this.refreshing = false;
    }
  }
}
