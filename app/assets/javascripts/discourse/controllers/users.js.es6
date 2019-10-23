import Controller from "@ember/controller";
import debounce from "discourse/lib/debounce";

export default Controller.extend({
  application: Ember.inject.controller(),
  queryParams: ["period", "order", "asc", "name", "group", "exclude_usernames"],
  period: "weekly",
  order: "likes_received",
  asc: null,
  name: "",
  group: null,
  exclude_usernames: null,

  showTimeRead: Ember.computed.equal("period", "all"),

  _setName: debounce(function() {
    this.set("name", this.nameInput);
  }, 500).observes("nameInput"),

  _showFooter: function() {
    this.set("application.showFooter", !this.get("model.canLoadMore"));
  }.observes("model.canLoadMore"),

  actions: {
    loadMore() {
      this.model.loadMore();
    }
  }
});
