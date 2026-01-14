import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";

export default class AdminGroupsIndexController extends Controller {
  @service store;

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

  async _debouncedFilter(filter) {
    this.set("filter", filter);
    await this._fetchGroups();
  }

  async _fetchGroups() {
    const params = {
      order: this.order,
      asc: this.asc,
      filter: this.filter,
      type: this.type,
    };
    const groups = await this.store.findAll("group", params);
    this.set("model.groups", groups);
  }
}
