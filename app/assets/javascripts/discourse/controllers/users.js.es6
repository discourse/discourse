import { equal } from "@ember/object/computed";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import discourseDebounce from "discourse/lib/debounce";
import { observes } from "discourse-common/utils/decorators";

export default Controller.extend({
  application: inject(),
  queryParams: ["period", "order", "asc", "name", "group", "exclude_usernames"],
  period: "weekly",
  order: "likes_received",
  asc: null,
  name: "",
  group: null,
  exclude_usernames: null,

  showTimeRead: equal("period", "all"),

  @observes("nameInput")
  _setName: discourseDebounce(function() {
    this.set("name", this.nameInput);
  }, 500),

  @observes("model.canLoadMore")
  _showFooter: function() {
    this.set("application.showFooter", !this.get("model.canLoadMore"));
  },

  actions: {
    loadMore() {
      this.model.loadMore();
    }
  }
});
