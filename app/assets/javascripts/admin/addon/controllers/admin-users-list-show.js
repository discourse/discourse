import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { observes } from "@ember-decorators/object";
import { computedI18n } from "discourse/lib/computed";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import CanCheckEmails from "discourse/mixins/can-check-emails";
import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import AdminUser from "admin/models/admin-user";

export default class AdminUsersListShowController extends Controller.extend(
  CanCheckEmails
) {
  @service dialog;

  @tracked bulkSelect = false;
  @tracked displayBulkActions = false;
  @tracked bulkSelectedUsers = null;

  query = null;
  order = null;
  asc = null;
  users = null;
  showEmails = false;
  refreshing = false;
  listFilter = null;

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

  @observes("listFilter")
  _filterUsers() {
    discourseDebounce(this, this.resetFilters, INPUT_DELAY);
  }

  resetFilters() {
    this._page = 1;
    this._results = [];
    this._canLoadMore = true;
    this._refreshUsers();
  }

  _refreshUsers() {
    if (!this._canLoadMore) {
      return;
    }

    const page = this._page;
    this.set("refreshing", true);

    AdminUser.findAll(this.query, {
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
    this.bulkSelectedUsers = null;
  }

  @action
  bulkSelectItemToggle(userId, event) {
    if (!this.bulkSelectedUsers) {
      this.bulkSelectedUsers = {};
    }

    if (event.target.checked) {
      this.bulkSelectedUsers[userId] = 1;
    } else {
      delete this.bulkSelectedUsers[userId];
    }
    this.displayBulkActions = Object.keys(this.bulkSelectedUsers).length > 0;
  }

  @action
  performBulkDelete() {
    const userIds = Object.keys(this.bulkSelectedUsers);
    const count = userIds.length;
    this.dialog.deleteConfirm({
      title: I18n.t("admin.users.bulk_actions.confirm_delete_title", {
        count,
      }),
      message: I18n.t("admin.users.bulk_actions.confirm_delete_body", {
        count,
      }),
      confirmButtonClass: "btn-danger",
      confirmButtonIcon: "trash-can",
      didConfirm: async () => {
        try {
          await ajax("/admin/users/destroy-bulk.json", {
            type: "DELETE",
            data: { user_ids: userIds },
          });
          this.bulkSelectedUsers = null;
          this.displayBulkActions = false;
          this.resetFilters();
        } catch (err) {
          this.dialog.alert(extractError(err));
        }
      },
    });
  }
}
