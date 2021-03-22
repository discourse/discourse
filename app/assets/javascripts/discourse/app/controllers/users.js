import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import discourseDebounce from "discourse-common/lib/debounce";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import { equal } from "@ember/object/computed";
import { longDate } from "discourse/lib/formatter";

export default Controller.extend({
  application: controller(),
  queryParams: ["period", "order", "asc", "name", "group", "exclude_usernames"],
  period: "weekly",
  order: "likes_received",
  asc: null,
  name: "",
  group: null,
  nameInput: null,
  exclude_usernames: null,
  isLoading: false,

  showTimeRead: equal("period", "all"),

  @discourseComputed("group")
  selectedGroupId(group) {
    let selectedGroup = this.availableGroups.findBy("name", group);

    return selectedGroup ? selectedGroup.id : null;
  },

  loadUsers(params) {
    this.set("isLoading", true);

    this.set("nameInput", params.name);

    this.store
      .find("directoryItem", params)
      .then((model) => {
        const lastUpdatedAt = model.get("resultSetMeta.last_updated_at");
        this.setProperties({
          model,
          lastUpdatedAt: lastUpdatedAt ? longDate(lastUpdatedAt) : null,
          period: params.period,
        });
      })
      .finally(() => {
        this.set("isLoading", false);
      });
  },

  @action
  onFilterChanged(filter) {
    discourseDebounce(this, this._setName, filter, 500);
  },

  _setName(name) {
    this.set("name", name);
  },

  @observes("model.canLoadMore")
  _showFooter() {
    this.set("application.showFooter", !this.get("model.canLoadMore"));
  },

  @action
  loadMore() {
    this.model.loadMore();
  },

  @action
  updateGroupParam(selectedGroupId, currentSelection) {
    this.set(
      "group",
      currentSelection.length
        ? currentSelection[currentSelection.length - 1].name
        : null
    );
  },
});
