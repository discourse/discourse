import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import CanCheckEmailsHelper from "discourse/lib/can-check-emails-helper";
import { computedI18n, setting } from "discourse/lib/computed";
import discourseDebounce from "discourse/lib/debounce";
import discourseComputed, { bind } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse-common/config/environment";
import { i18n } from "discourse-i18n";
import BulkUserDeleteConfirmation from "admin/components/bulk-user-delete-confirmation";
import AdminUser from "admin/models/admin-user";

const MAX_BULK_SELECT_LIMIT = 100;

export default class AdminUsersListShowController extends Controller {
  @service dialog;
  @service modal;
  @service toasts;

  @tracked bulkSelect = false;
  @tracked displayBulkActions = false;
  @tracked bulkSelectedUserIdsSet = new Set();
  @tracked bulkSelectedUsersMap = {};
  @setting("moderators_view_emails") canModeratorsViewEmails;

  query = null;
  order = null;
  asc = null;
  users = null;
  showEmails = false;
  refreshing = false;
  listFilter = null;
  lastSelected = null;

  @computedI18n("search_hint") searchHint;

  _page = 1;
  _results = [];
  _canLoadMore = true;

  @discourseComputed("query")
  title(query) {
    return i18n("admin.users.titles." + query);
  }

  @discourseComputed("showEmails")
  columnCount(showEmails) {
    let colCount = 7; // note that the first column is hardcoded in the template

    if (showEmails) {
      colCount += 1;
    }

    if (this.siteSettings.must_approve_users) {
      colCount += 1;
    }

    return colCount;
  }

  @computed("model.id", "currentUser.id")
  get canCheckEmails() {
    return new CanCheckEmailsHelper(
      this.model,
      this.canModeratorsViewEmails,
      this.currentUser
    ).canCheckEmails;
  }

  @computed("model.id", "currentUser.id")
  get canAdminCheckEmails() {
    return new CanCheckEmailsHelper(
      this.model,
      this.canModeratorsViewEmails,
      this.currentUser
    ).canAdminCheckEmails;
  }

  @computed("query")
  get showSilenceReason() {
    return this.query === "silenced";
  }

  resetFilters() {
    this._page = 1;
    this._results = [];
    this._canLoadMore = true;
    return this._refreshUsers();
  }

  _refreshUsers() {
    if (!this._canLoadMore) {
      return;
    }

    const page = this._page;
    this.set("refreshing", true);

    return AdminUser.findAll(this.query, {
      filter: this.listFilter,
      show_emails: this.showEmails,
      order: this.order,
      asc: this.asc,
      page,
    })
      .then((result) => {
        this._results[page] = result;
        this.set("users", this._results.flat());

        if (result.length === 0) {
          this._canLoadMore = false;
        }
      })
      .finally(() => {
        this.set("refreshing", false);
      });
  }

  @action
  onListFilterChange(event) {
    this.set("listFilter", event.target.value);
    discourseDebounce(this, this.resetFilters, INPUT_DELAY);
  }

  @action
  loadMore() {
    this._page += 1;
    this._refreshUsers();
  }

  @action
  toggleEmailVisibility() {
    this.toggleProperty("showEmails");
    this.resetFilters();
  }

  @action
  updateOrder(field, asc) {
    this.setProperties({
      order: field,
      asc,
    });
  }

  @action
  toggleBulkSelect() {
    this.bulkSelect = !this.bulkSelect;
    this.displayBulkActions = false;
    this.bulkSelectedUsersMap = {};
    this.bulkSelectedUserIdsSet = new Set();
  }

  @action
  bulkSelectItemToggle(userId, event) {
    if (event.target.checked) {
      if (!this.#canBulkSelectMoreUsers(1)) {
        this.#showBulkSelectionLimitToast(event);
        return;
      }

      if (event.shiftKey && this.lastSelected) {
        const list = Array.from(
          document.querySelectorAll(
            "input.directory-table__cell-bulk-select:not([disabled])"
          )
        );
        const lastSelectedIndex = list.indexOf(this.lastSelected);
        if (lastSelectedIndex !== -1) {
          const newSelectedIndex = list.indexOf(event.target);
          const start = Math.min(lastSelectedIndex, newSelectedIndex);
          const end = Math.max(lastSelectedIndex, newSelectedIndex);

          if (!this.#canBulkSelectMoreUsers(end - start)) {
            this.#showBulkSelectionLimitToast(event);
            return;
          }

          list.slice(start, end).forEach((input) => {
            input.checked = true;
            this.#addUserToBulkSelection(parseInt(input.dataset.userId, 10));
          });
        }
      }
      this.#addUserToBulkSelection(userId);
      this.lastSelected = event.target;
    } else {
      this.bulkSelectedUserIdsSet.delete(userId);
      delete this.bulkSelectedUsersMap[userId];
    }

    this.displayBulkActions = this.bulkSelectedUserIdsSet.size > 0;
  }

  @bind
  async afterBulkDelete() {
    await this.resetFilters();
    this.bulkSelectedUsersMap = {};
    this.bulkSelectedUserIdsSet = new Set();
    this.displayBulkActions = false;
  }

  @action
  openBulkDeleteConfirmation() {
    this.modal.show(BulkUserDeleteConfirmation, {
      model: {
        userIds: Array.from(this.bulkSelectedUserIdsSet),
        afterBulkDelete: this.afterBulkDelete,
      },
    });
  }

  #addUserToBulkSelection(userId) {
    this.bulkSelectedUserIdsSet.add(userId);
    this.bulkSelectedUsersMap[userId] = 1;
  }

  #canBulkSelectMoreUsers(count) {
    return this.bulkSelectedUserIdsSet.size + count <= MAX_BULK_SELECT_LIMIT;
  }

  #showBulkSelectionLimitToast(event) {
    this.toasts.error({
      duration: 3000,
      data: {
        message: i18n("admin.users.bulk_actions.too_many_selected_users", {
          count: MAX_BULK_SELECT_LIMIT,
        }),
      },
    });
    event.preventDefault();
  }
}
