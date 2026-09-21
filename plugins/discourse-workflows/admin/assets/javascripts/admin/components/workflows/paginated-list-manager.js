import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class PaginatedListManager extends Component {
  // eslint-disable-next-line discourse/no-unused-services -- used by subclasses
  @service currentUser;
  // eslint-disable-next-line discourse/no-unused-services -- used by subclasses
  @service dialog;
  // eslint-disable-next-line discourse/no-unused-services -- used by subclasses
  @service modal;

  @tracked items = null;
  @tracked loadError = null;
  @tracked loadMoreUrl = null;
  @tracked totalRows = 0;
  @tracked loadingMore = false;

  constructor() {
    super(...arguments);
    this.loadItems();
  }

  get apiUrl() {
    return `${this.basePath}.json`;
  }

  get canLoadMore() {
    return this.items && this.items.length < this.totalRows;
  }

  get isLoading() {
    return this.items === null;
  }

  async loadItems() {
    this.loadError = null;
    try {
      const result = await ajax(this.apiUrl);
      this.items = result[this.collectionKey];
      this.loadMoreUrl = result.meta?.load_more_url;
      this.totalRows = result.meta?.total_rows ?? this.items.length;
    } catch (e) {
      this.loadError = e;
      this.items = [];
      popupAjaxError(e);
    }
  }

  @action
  async loadMore() {
    if (!this.loadMoreUrl || !this.canLoadMore || this.loadingMore) {
      return;
    }

    this.loadingMore = true;
    try {
      const result = await ajax(this.loadMoreUrl);
      this.items = [...this.items, ...result[this.collectionKey]];
      this.loadMoreUrl = result.meta?.load_more_url;
      this.totalRows = result.meta?.total_rows ?? this.totalRows;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingMore = false;
    }
  }
}
