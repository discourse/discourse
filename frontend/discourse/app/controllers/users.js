import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { service } from "@ember/service";
import EditUserDirectoryColumnsModal from "discourse/components/modal/edit-user-directory-columns";
import EditUserDirectoryColumnsModalReorderable from "discourse/components/modal/edit-user-directory-columns-reorderable";
import discourseDebounce from "discourse/lib/debounce";
import { longDate } from "discourse/lib/formatter";
import Group from "discourse/models/group";

/**
 * @typedef {Object} DirectoryParams
 * @property {string} [period]
 * @property {string} [order]
 * @property {boolean | string | null} [asc]
 * @property {string} [name]
 * @property {string | null} [group]
 * @property {string | null} [exclude_usernames]
 * @property {string | null} [exclude_groups]
 * @property {string} [user_field_ids]
 * @property {string} [plugin_column_ids]
 */
export default class UsersController extends Controller {
  @service modal;
  @service siteSettings;

  @tracked period = "weekly";

  queryParams = [
    "period",
    "order",
    "asc",
    "name",
    "group",
    "exclude_usernames",
    "exclude_groups",
  ];

  order = "";

  /** @type {boolean | string | null} */
  asc = null;
  name = "";

  /** @type {string | null | undefined} */
  group = null;

  /** @type {string | null | undefined} */
  nameInput = null;

  /** @type {string | null} */
  exclude_usernames = null;

  /** @type {string | null} */
  exclude_groups = null;
  isLoading = false;

  /** @type {{ id: number, name: string, type: string, position: number, icon: string | null, user_field_id: number | null }[] | null} */
  columns = null;

  /** @type {{ name: string, id: string }[] | null} */
  groupOptions = null;

  /** @type {DirectoryParams | null} */
  params = null;

  @computed("currentUser", "groupOptions")
  get showGroupFilter() {
    return this.currentUser && this.groupOptions;
  }

  @dependentKeyCompat
  get showTimeRead() {
    return this.period === "all";
  }

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
  }

  loadGroups() {
    if (this.currentUser) {
      return Group.findAll({ ignore_automatic: true }).then((groups) => {
        const groupOptions = groups
          .filter((group) => group.can_see_members)
          .map((group) => {
            return {
              name: group.full_name || group.name,
              id: group.name,
            };
          });
        this.set("groupOptions", groupOptions);
      });
    }
  }

  @action
  groupChanged(_, groupAttrs) {
    // First param is the group name, which include none or 'all groups'. Ignore this and look at second param.
    this.set("group", groupAttrs?.id);
  }

  @action
  showEditColumnsModal() {
    // TODO (ui-kit-reorderable-list-cleanup) drop the branch and the legacy
    // component once the change ships.
    const Modal = this.siteSettings.enable_new_reordering_controls
      ? EditUserDirectoryColumnsModalReorderable
      : EditUserDirectoryColumnsModal;

    this.modal.show(Modal);
  }

  @action
  onUsernameFilterChanged(filter) {
    discourseDebounce(this, this._setUsernameFilter, filter, 500);
  }

  @action
  updateOrderAndAsc(order, asc) {
    this.setProperties({ order, asc });
  }

  @action
  loadMore() {
    this.model.loadMore();
  }

  _setUsernameFilter(username) {
    this.setProperties({
      name: username,
      "params.name": username,
    });
    this.loadUsers();
  }
}
