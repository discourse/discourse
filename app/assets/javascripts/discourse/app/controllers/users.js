import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import discourseDebounce from "discourse-common/lib/debounce";
import showModal from "discourse/lib/show-modal";
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
  nameInput: null,
  exclude_usernames: null,
  isLoading: false,
  columns: null,

  showTimeRead: equal("period", "all"),

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
  showEditColumnsModal() {
    showModal("edit-user-directory-columns");
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
});
