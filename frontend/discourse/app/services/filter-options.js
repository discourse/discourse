import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";

// enough to draw category and tag tokens while the full list loads
const BASIC_OPTIONS = [
  { name: "category:", alias: "categories:", type: "category" },
  { name: "tag:", alias: "tags:", type: "tag" },
];

/**
 * The topic filters available to the current user, fetched once and shared by
 * every filter bar outside the filter page (which gets them with its topics).
 */
export default class FilterOptions extends Service {
  @tracked loaded = null;

  #request = null;

  get options() {
    return this.loaded ?? BASIC_OPTIONS;
  }

  load() {
    this.#request ??= ajax("/filter/options.json")
      .then((result) => (this.loaded = result.options))
      .catch(() => (this.#request = null));

    return this.#request;
  }
}
