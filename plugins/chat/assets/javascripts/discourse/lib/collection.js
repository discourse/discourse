import { tracked } from "@glimmer/tracking";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";

/**
 * Handles a paginated API response.
 */
export default class Collection {
  @tracked items = [];
  @tracked meta = {};
  @tracked loading = false;
  @tracked fetchedOnce = false;

  constructor(resourceURL, handler, params = {}) {
    this._resourceURL = resourceURL;
    this._handler = handler;
    this._params = params;
    this._fetchedAll = false;
  }

  get loadMoreURL() {
    return this.meta?.load_more_url;
  }

  get totalRows() {
    return this.meta?.total_rows;
  }

  get length() {
    return this.items?.length;
  }

  // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Iteration_protocols
  [Symbol.iterator]() {
    let index = 0;

    return {
      next: () => {
        if (index < this.length) {
          return { value: this.items[index++], done: false };
        } else {
          return { done: true };
        }
      },
    };
  }

  /**
   * Loads first batch of results
   * @returns {Promise}
   */
  @bind
  load(params = {}) {
    if (
      this.loading ||
      this._fetchedAll ||
      (this.totalRows && this.items.length >= this.totalRows)
    ) {
      return Promise.resolve();
    }

    this.loading = true;

    let endpoint;
    if (this.loadMoreURL) {
      endpoint = this.loadMoreURL;
    } else {
      const filteredQueryParams = Object.entries(params).filter(
        ([, v]) => v !== undefined
      );

      const queryString = new URLSearchParams(filteredQueryParams).toString();
      endpoint = this._resourceURL + (queryString ? `?${queryString}` : "");
    }

    return this.#fetch(endpoint)
      .then((result) => {
        const items = this._handler(result);

        if (items.length) {
          this.items = (this.items ?? []).concat(items);
        }

        if (!items.length || items.length < params.limit) {
          this._fetchedAll = true;
        }

        this.meta = result.meta;
        this.fetchedOnce = true;
      })
      .finally(() => {
        this.loading = false;
      });
  }

  #fetch(url) {
    return ajax(url, { type: "GET", data: this._params });
  }
}
