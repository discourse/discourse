import { equal } from "@ember/object/computed";
import Controller, { inject as controller } from "@ember/controller";
import discourseDebounce from "discourse/lib/debounce";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import { longDate } from "discourse/lib/formatter";

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

  @discourseComputed("group")
  selectedGroupId(group) {
    let selectedGroup = this.get("availableGroups").find(
      (item) => item.name === group
    );
    return selectedGroup ? selectedGroup.id : -1;
  },

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
  _setName: discourseDebounce(function () {
    this.set("name", this.nameInput);
  }, 500),

  @observes("model.canLoadMore")
  _showFooter: function () {
    this.set("application.showFooter", !this.get("model.canLoadMore"));
  },

  actions: {
    loadMore() {
      this.model.loadMore();
    },

    updateGroupParam(selectedGroups, currentSelection) {
      this.set("group", currentSelection ? currentSelection.name : null);
    },
  },
});
