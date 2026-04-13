import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class CrudManager extends Component {
  // eslint-disable-next-line discourse/no-unused-services -- used by subclasses
  @service currentUser;
  // eslint-disable-next-line discourse/no-unused-services -- used by subclasses
  @service dialog;
  // eslint-disable-next-line discourse/no-unused-services -- used by subclasses
  @service modal;

  @tracked items = null;
  @tracked loadMoreUrl = null;
  @tracked totalRows = 0;
  @tracked loadingMore = false;

  constructor() {
    super(...arguments);
    this.loadItems();
  }

  get metaLoadMoreKey() {
    return `load_more_${this.itemsKey}`;
  }

  get metaTotalRowsKey() {
    return `total_rows_${this.itemsKey}`;
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
    try {
      const result = await ajax(this.apiUrl);
      this.items = result[this.itemsKey];
      this.loadMoreUrl = result.meta?.[this.metaLoadMoreKey];
      this.totalRows =
        result.meta?.[this.metaTotalRowsKey] ?? result[this.itemsKey].length;
    } catch (e) {
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
      this.items = [...this.items, ...result[this.itemsKey]];
      this.loadMoreUrl = result.meta?.[this.metaLoadMoreKey];
      this.totalRows = result.meta?.[this.metaTotalRowsKey] ?? this.totalRows;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingMore = false;
    }
  }
}
