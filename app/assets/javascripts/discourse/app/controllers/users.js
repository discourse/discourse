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
  order: "",
  asc: null,
  name: "",
  group: null,
  nameInput: null,
  exclude_usernames: null,
  isLoading: false,
  columns: null,
  groupsOptions: null,

  showTimeRead: equal("period", "all"),

  loadUsers(params) {
    this.set("isLoading", true);

    this.set("nameInput", params.name);
    this.set("order", params.order);

    const custom_field_columns = this.columns.filter((c) => !c.automatic);
    const user_field_ids = custom_field_columns
      .map((c) => c.user_field_id)
      .join("|");

    this.store
      .find("directoryItem", Object.assign(params, { user_field_ids }))
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

  loadGroups() {
    this.store.findAll("group").then((groups) => {
      const groupOptions = [];
      groups.forEach((group) => {
        groupOptions.push({
          name: group.name,
          id: group.id,
        });
      });
      this.set("groupOptions", groupOptions);
    });
  },

  @action
  groupChanged(_, groupAttrs) {
    // First param is the group name, which include none or 'all groups'. Ignore this and look at second param.
    this.set("group", groupAttrs.id ? groupAttrs.name : null);
  },

  @action
  showEditColumnsModal() {
    showModal("edit-user-directory-columns");
  },

  @action
  onUsernameFilterChanged(filter) {
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
