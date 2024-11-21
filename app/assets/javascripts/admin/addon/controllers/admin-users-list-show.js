import Controller from "@ember/controller";
import { action } from "@ember/object";
import { observes } from "@ember-decorators/object";
import { computedI18n } from "discourse/lib/computed";
import CanCheckEmails from "discourse/mixins/can-check-emails";
import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import AdminUser from "admin/models/admin-user";

export default class AdminUsersListShowController extends Controller.extend(
  CanCheckEmails
) {
  model = null;
  query = null;
  order = null;
  asc = null;
  showEmails = false;
  refreshing = false;
  listFilter = null;
  selectAll = false;

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
        this.set("model", this._results.flat());

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
}
