import Controller, { inject as controller } from "@ember/controller";
import Group from "discourse/models/group";
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
  params: null,

  showTimeRead: equal("period", "all"),

  loadUsers(params = null) {
    if (params) {
      this.set("params", params);
    }

    this.setProperties({
      isLoading: true,
      nameInput: this.params.name,
      order: this.params.order,
    });

    const userFieldIds = this.columns
      .filter((c) => c.type === "user_field")
      .map((c) => c.user_field_id)
      .join("|");
    const pluginColumnIds = this.columns
      .filter((c) => c.type === "plugin")
      .map((c) => c.id)
      .join("|");

    return this.store
      .find(
        "directoryItem",
        Object.assign(this.params, {
          user_field_ids: userFieldIds,
          plugin_column_ids: pluginColumnIds,
        })
      )
      .then((model) => {
        const lastUpdatedAt = model.get("resultSetMeta.last_updated_at");
        this.setProperties({
          model,
          lastUpdatedAt: lastUpdatedAt ? longDate(lastUpdatedAt) : null,
          period: this.params.period,
        });
      })
      .finally(() => {
        this.set("isLoading", false);
      });
  },

  loadGroups() {
    return Group.findAll({ ignore_automatic: true }).then((groups) => {
      const groupOptions = groups.map((group) => {
        return {
          name: group.full_name || group.name,
          id: group.name,
        };
      });
      this.set("groupOptions", groupOptions);
    });
  },

  @action
  groupChanged(_, groupAttrs) {
    // First param is the group name, which include none or 'all groups'. Ignore this and look at second param.
    this.set("group", groupAttrs.id);
  },

  @action
  showEditColumnsModal() {
    showModal("edit-user-directory-columns");
  },

  @action
  onUsernameFilterChanged(filter) {
    discourseDebounce(this, this._setUsernameFilter, filter, 500);
  },

  _setUsernameFilter(username) {
    this.setProperties({
      name: username,
      "params.name": username,
    });
    this.loadUsers();
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
