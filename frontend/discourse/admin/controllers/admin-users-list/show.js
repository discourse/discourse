import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import { service } from "@ember/service";
import BulkUserDeleteConfirmation from "discourse/admin/components/bulk-user-delete-confirmation";
import BulkUserSuspendConfirmation from "discourse/admin/components/bulk-user-suspend-confirmation";
import AdminUser from "discourse/admin/models/admin-user";
import CanCheckEmailsHelper from "discourse/lib/can-check-emails-helper";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";
import DiscourseURL, { applyQueryParams } from "discourse/lib/url";
import { i18n } from "discourse-i18n";

const MAX_BULK_SELECT_LIMIT = 100;
const USERS_PER_PAGE = 100;

export default class AdminUsersListShowController extends Controller {
  @service modal;
  @service router;
  @service toasts;

  @tracked bulkSelect = false;
  @tracked displayBulkActions = false;
  @tracked bulkSelectedUsersMap = {};

  @tracked activation = null;
  @tracked refreshing = false;
  @tracked listFilter = null;
  @tracked initialFilter = null;

  @tracked query = null;
  @tracked order = null;
  @tracked asc = null;
  @tracked showEmails = false;

  lastSelected = null;

  #page = 1;
  #results = trackedArray();
  #canLoadMore = true;

  get users() {
    return this.#results.flat();
  }

  get title() {
    return i18n("admin.users.titles." + this.query);
  }

  get columnCount() {
    let colCount = 7; // note that the first column is hardcoded in the template

    if (this.showEmails) {
      colCount += 1;
    }

    if (this.siteSettings.must_approve_users) {
      colCount += 1;
    }

    return colCount;
  }

  get canCheckEmails() {
    return new CanCheckEmailsHelper(
      this.model?.id,
      this.siteSettings.moderators_view_emails,
      this.currentUser
    ).canCheckEmails;
  }

  get showSilenceReason() {
    return this.query === "silenced";
  }

  get showSuspendReason() {
    return this.query === "suspended";
  }

  get showActivationFilter() {
    return this.query === "new";
  }

  get showEmptyState() {
    return (
      !this.refreshing &&
      this.users.length === 0 &&
      !this.listFilter &&
      !this.activation
    );
  }

  get bulkSelectedUsers() {
    return Object.values(this.bulkSelectedUsersMap);
  }

  resetFilters() {
    this.#page = 1;
    this.#results.length = 0;
    this.#canLoadMore = true;
    return this.#refreshUsers();
  }

  stripHtml(html) {
    if (!html) {
      return "";
    }
    const doc = new DOMParser().parseFromString(html, "text/html");
    return doc.body.textContent || "";
  }

  @action
  onListFilterChange(event) {
    this.listFilter = event.target.value;
    discourseDebounce(this, this.resetFilters, INPUT_DELAY);
  }

  @action
  onResetFilters() {
    this.listFilter = null;
    this.activation = null;
    DiscourseURL.replaceState(
      applyQueryParams(this.router.currentURL, {
        username: null,
        filter: null,
        activation: null,
      })
    );
    this.resetFilters();
  }

  @action
  loadMore() {
    if (this.refreshing) {
      return;
    }
    this.#page += 1;
    this.#refreshUsers();
  }

  @action
  toggleEmailVisibility() {
    this.showEmails = !this.showEmails;
    this.resetFilters();
  }

  @action
  updateOrder(field, asc) {
    this.order = field;
    this.asc = asc;
    DiscourseURL.replaceState(
      applyQueryParams(this.router.currentURL, { order: field, asc })
    );
    this.resetFilters();
  }

  @action
  onActivationChange(value) {
    this.activation = value === "all" ? null : value;
    this.resetFilters();
  }

  @action
  toggleBulkSelect() {
    this.bulkSelect = !this.bulkSelect;
    this.displayBulkActions = false;
    this.bulkSelectedUsersMap = {};
  }

  @action
  bulkSelectAll() {
    const unchecked = [
      ...document.querySelectorAll(
        "input.directory-table__cell-bulk-select:not(:checked)"
      ),
    ];
    const remaining = MAX_BULK_SELECT_LIMIT - this.bulkSelectedUsers.length;
    unchecked.slice(0, remaining).forEach((input) => input.click());

    if (unchecked.length > remaining) {
      this.#showBulkSelectionLimitToast();
    }
  }

  @action
  bulkClearAll() {
    document
      .querySelectorAll("input.directory-table__cell-bulk-select:checked")
      .forEach((input) => input.click());
  }

  @action
  bulkSelectItemToggle(userId, event) {
    if (event.target.checked) {
      if (!this.#canBulkSelectMoreUsers(1)) {
        event.preventDefault();
        this.#showBulkSelectionLimitToast();
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
            event.preventDefault();
            this.#showBulkSelectionLimitToast();
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
      delete this.bulkSelectedUsersMap[userId];
    }

    this.displayBulkActions = this.bulkSelectedUsers.length > 0;
  }

  @bind
  async afterBulkAction() {
    await this.resetFilters();
    this.bulkSelectedUsersMap = {};
    this.displayBulkActions = false;
  }

  @action
  openBulkDeleteConfirmation() {
    this.#openBulkActionConfirmation({
      canBeActioned: (user) => user.can_be_deleted,
      emptyMessageKey: "admin.users.bulk_actions.no_users_can_be_deleted",
      modal: BulkUserDeleteConfirmation,
    });
  }

  @action
  openBulkSuspendConfirmation() {
    this.#openBulkActionConfirmation({
      canBeActioned: (user) => user.can_be_suspended,
      emptyMessageKey: "admin.users.bulk_actions.no_users_can_be_suspended",
      modal: BulkUserSuspendConfirmation,
    });
  }

  #openBulkActionConfirmation({ canBeActioned, emptyMessageKey, modal }) {
    const userIds = this.bulkSelectedUsers
      .filter(canBeActioned)
      .map((user) => user.id);

    if (userIds.length === 0) {
      this.toasts.error({
        duration: "short",
        data: { message: i18n(emptyMessageKey) },
      });
      return;
    }

    this.modal.show(modal, {
      model: { userIds, afterBulkAction: this.afterBulkAction },
    });
  }

  #addUserToBulkSelection(userId) {
    this.bulkSelectedUsersMap[userId] = this.users.find(
      (user) => user.id === userId
    );
  }

  #canBulkSelectMoreUsers(count) {
    return this.bulkSelectedUsers.length + count <= MAX_BULK_SELECT_LIMIT;
  }

  #showBulkSelectionLimitToast() {
    this.toasts.error({
      duration: "short",
      data: {
        message: i18n("admin.users.bulk_actions.too_many_selected_users", {
          count: MAX_BULK_SELECT_LIMIT,
        }),
      },
    });
  }

  #refreshUsers() {
    if (!this.#canLoadMore) {
      return;
    }

    const page = this.#page;
    this.refreshing = true;

    return AdminUser.findAll(this.query, {
      filter: this.listFilter,
      show_emails: this.showEmails,
      order: this.order,
      asc: this.asc,
      activation: this.activation,
      page,
    })
      .then((result) => {
        this.#results[page] = result;
        if (result.length < USERS_PER_PAGE) {
          this.#canLoadMore = false;
        }
      })
      .finally(() => {
        this.refreshing = false;
      });
  }
}
