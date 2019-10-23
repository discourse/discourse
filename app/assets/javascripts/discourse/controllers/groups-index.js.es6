import Controller from "@ember/controller";
import debounce from "discourse/lib/debounce";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";

export default Controller.extend({
  application: Ember.inject.controller(),
  queryParams: ["order", "asc", "filter", "type"],
  order: null,
  asc: null,
  filter: "",
  type: null,

  @computed("model.extras.type_filters")
  types(typeFilters) {
    const types = [];

    if (typeFilters) {
      typeFilters.forEach(type => {
        types.push({ id: type, name: I18n.t(`groups.index.${type}_groups`) });
      });
    }

    return types;
  },

  @observes("filterInput")
  _setFilter: debounce(function() {
    this.set("filter", this.filterInput);
  }, 500),

  @observes("model.canLoadMore")
  _showFooter() {
    this.set("application.showFooter", !this.get("model.canLoadMore"));
  },

  actions: {
    loadMore() {
      this.model.loadMore();
    },

    new() {
      this.transitionToRoute("groups.new");
    }
  }
});
