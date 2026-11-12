import Controller from "@ember/controller";
import { action } from "@ember/object";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";

export default class GroupsIndexController extends Controller {
  queryParams = ["order", "asc", "filter", "type"];

  /** @type {string | null} */
  order = null;

  /** @type {boolean | string | null} */
  asc = null;
  filter = "";

  /** @type {string | null} */
  type = null;

  /** @type {import("discourse/models/result-set").default | null} */
  groups = null;

  @action
  onTypeChanged(type) {
    this.set("type", type);
  }

  @action
  onFilterChanged(filter) {
    discourseDebounce(this, this._debouncedFilter, filter, INPUT_DELAY);
  }

  _debouncedFilter(filter) {
    this.set("filter", filter);
  }
}
