import Controller from "@ember/controller";
import { action } from "@ember/object";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";

export default class GroupsIndexController extends Controller {
  queryParams = ["order", "asc", "filter", "type"];
  order = null;
  asc = null;
  filter = "";
  type = null;
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
