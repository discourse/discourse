import I18n from "I18n";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import Controller from "@ember/controller";
import discourseDebounce from "discourse/lib/debounce";
import { i18n } from "discourse/lib/computed";
import AdminUser from "admin/models/admin-user";
import CanCheckEmails from "discourse/mixins/can-check-emails";
import { INPUT_DELAY } from "discourse-common/config/environment";

export default Controller.extend(CanCheckEmails, {
  model: null,
  query: null,
  order: null,
  asc: null,
  showEmails: false,
  refreshing: false,
  listFilter: null,
  selectAll: false,
  searchHint: i18n("search_hint"),

  init() {
    this._super(...arguments);

    this._page = 1;
    this._results = [];
    this._canLoadMore = true;
  },

  @discourseComputed("query")
  title(query) {
    return I18n.t("admin.users.titles." + query);
  },

  @observes("listFilter")
  _filterUsers: discourseDebounce(function() {
    this.resetFilters();
  }, INPUT_DELAY),

  resetFilters() {
    this._page = 1;
    this._results = [];
    this._canLoadMore = true;
    this._refreshUsers();
  },

  _refreshUsers() {
    if (!this._canLoadMore) {
      return;
    }

    this.set("refreshing", true);

    AdminUser.findAll(this.query, {
      filter: this.listFilter,
      show_emails: this.showEmails,
      order: this.order,
      asc: this.asc,
      page: this._page
    })
      .then(result => {
        if (!result || result.length === 0) {
          this._canLoadMore = false;
        }

        this._results = this._results.concat(result);
        this.set("model", this._results);
      })
      .finally(() => this.set("refreshing", false));
  },

  actions: {
    loadMore() {
      this._page += 1;
      this._refreshUsers();
    },

    toggleEmailVisibility() {
      this.toggleProperty("showEmails");
      this.resetFilters();
    }
  }
});
