/** @module Collection */

import { ajax } from "discourse/lib/ajax";
import { tracked } from "@glimmer/tracking";
import { bind } from "discourse-common/utils/decorators";
import { Promise } from "rsvp";

/**
 * Handles a paginated API response.
 *
 * @class
 */
export default class Collection {
  @tracked items = [];
  @tracked meta = {};
  @tracked loading = false;

  /**
   * Create a Collection instance
   * @param {string} resourceURL - the API endpoint to call
   * @param {callback} handler - anonymous function used to handle the response
   */
  constructor(resourceURL, handler) {
    this._resourceURL = resourceURL;
    this._handler = handler;
    this._fetchedAll = false;
  }

  get loadMoreURL() {
    return this.meta.load_more_url;
  }

  get totalRows() {
    return this.meta.total_rows;
  }

  get length() {
    return this.items.length;
  }

  // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Iteration_protocols
  [Symbol.iterator]() {
    let index = 0;

    return {
      next: () => {
        if (index < this.items.length) {
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
    this._fetchedAll = false;

    if (this.loading) {
      return Promise.resolve();
    }

    this.loading = true;

    const filteredQueryParams = Object.entries(params).filter(
      ([, v]) => v !== undefined
    );
    const queryString = new URLSearchParams(filteredQueryParams).toString();

    const endpoint = this._resourceURL + (queryString ? `?${queryString}` : "");
    return this.#fetch(endpoint)
      .then((result) => {
        this.items = this._handler(result);
        this.meta = result.meta;
      })
      .finally(() => {
        this.loading = false;
      });
  }

  /**
   * Attempts to load more results
   * @returns {Promise}
   */
  @bind
  loadMore() {
    let promise = Promise.resolve();

    if (this.loading) {
      return promise;
    }

    if (
      this._fetchedAll ||
      (this.totalRows && this.items.length >= this.totalRows)
    ) {
      return promise;
    }

    this.loading = true;

    if (this.loadMoreURL) {
      promise = this.#fetch(this.loadMoreURL).then((result) => {
        const newItems = this._handler(result);

        if (newItems.length) {
          this.items = this.items.concat(newItems);
        } else {
          this._fetchedAll = true;
        }
        this.meta = result.meta;
      });
    }

    return promise.finally(() => {
      this.loading = false;
    });
  }

  #fetch(url) {
    return ajax(url, { type: "GET" });
  }
}
