import Controller from "@ember/controller";
import I18n from "I18n";
import { INPUT_DELAY } from "discourse-common/config/environment";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import discourseDebounce from "discourse-common/lib/debounce";
import { inject as service } from "@ember/service";

export default Controller.extend({
  router: service(),
  queryParams: ["order", "asc", "filter", "type"],
  order: null,
  asc: null,
  filter: "",
  type: null,
  groups: null,
  isLoading: false,

  @discourseComputed("groups.extras.type_filters")
  types(typeFilters) {
    const types = [];

    if (typeFilters) {
      typeFilters.forEach((type) =>
        types.push({ id: type, name: I18n.t(`groups.index.${type}_groups`) })
      );
    }

    return types;
  },

  loadGroups(params) {
    this.set("isLoading", true);

    this.store
      .findAll("group", params)
      .then((groups) => {
        this.set("groups", groups);
      })
      .finally(() => this.set("isLoading", false));
  },

  @action
  onFilterChanged(filter) {
    discourseDebounce(this, this._debouncedFilter, filter, INPUT_DELAY);
  },

  @action
  loadMore() {
    this.groups && this.groups.loadMore();
  },

  @action
  new() {
    this.router.transitionTo("groups.new");
  },

  _debouncedFilter(filter) {
    this.set("filter", filter);
  },
});
