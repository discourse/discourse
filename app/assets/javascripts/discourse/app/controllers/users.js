import Controller, { inject as controller } from "@ember/controller";
import discourseDebounce from "discourse-common/lib/debounce";
import { equal } from "@ember/object/computed";
import { longDate } from "discourse/lib/formatter";
import { observes } from "discourse-common/utils/decorators";

export default Controller.extend({
  application: controller(),
  queryParams: ["period", "order", "asc", "name", "group", "exclude_usernames"],
  period: "weekly",
  order: "likes_received",
  asc: null,
  name: "",
  group: null,
  exclude_usernames: null,
  isLoading: false,

  showTimeRead: equal("period", "all"),

  loadUsers(params) {
    this.set("isLoading", true);

    this.store
      .find("directoryItem", params)
      .then((model) => {
        const lastUpdatedAt = model.get("resultSetMeta.last_updated_at");
        this.setProperties({
          model,
          lastUpdatedAt: lastUpdatedAt ? longDate(lastUpdatedAt) : null,
          period: params.period,
          nameInput: params.name,
        });
      })
      .finally(() => {
        this.set("isLoading", false);
      });
  },

  @observes("nameInput")
  _setName() {
    discourseDebounce(
      this,
      function () {
        this.set("name", this.nameInput);
      },
      500
    );
  },

  @observes("model.canLoadMore")
  _showFooter: function () {
    this.set("application.showFooter", !this.get("model.canLoadMore"));
  },

  actions: {
    loadMore() {
      this.model.loadMore();
    },
  },
});
