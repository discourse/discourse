import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import LegacyArrayLikeObject from "discourse/lib/legacy-array-like-object";
import type StoreService from "discourse/services/store";

export default class ResultSet<T = unknown> extends LegacyArrayLikeObject<T> {
  /** Endpoint-specific response extras, optionally wrapped by the model's extras class. */
  @tracked extras: unknown;
  @tracked findArgs: object | null | undefined;

  @tracked loadMoreUrl: string | null | undefined = null;
  @tracked loading = false;
  @tracked loadingMore = false;

  @tracked refreshUrl: string | null | undefined = null;
  @tracked refreshing = false;

  /** Unmodified endpoint-specific metadata; narrow it before reading its fields. */
  @tracked resultSetMeta: unknown;
  @tracked totalRows = 0;

  store: StoreService | null = null;
  __type: string | undefined;

  get warnContext() {
    return "__type: " + this.__type;
  }

  @dependentKeyCompat
  get canLoadMore() {
    return this.content.length < this.totalRows;
  }

  @action
  async loadMore(): Promise<void> {
    const loadMoreUrl = this.loadMoreUrl;
    if (!loadMoreUrl) {
      return;
    }

    const totalRows = this.totalRows;
    if (this.content.length < totalRows && !this.loadingMore) {
      this.loadingMore = true;

      // Store hydration supplies store and __type before pagination is used.
      try {
        return await this.store!.appendResults(this, this.__type!, loadMoreUrl);
      } finally {
        this.loadingMore = false;
      }
    }
  }

  @action
  async refresh(): Promise<void> {
    if (this.refreshing) {
      return;
    }

    const refreshUrl = this.refreshUrl;
    if (!refreshUrl) {
      return;
    }

    this.refreshing = true;
    // Store hydration supplies store and __type before refresh is used.
    try {
      return await this.store!.refreshResults(this, this.__type!, refreshUrl);
    } finally {
      this.refreshing = false;
    }
  }
}
