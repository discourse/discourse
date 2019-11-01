import Controller from "@ember/controller";
import debounce from "discourse/lib/debounce";
import { i18n } from "discourse/lib/computed";
import AdminUser from "admin/models/admin-user";
import CanCheckEmails from "discourse/mixins/can-check-emails";
import computed from "ember-addons/ember-computed-decorators";

export default Controller.extend(CanCheckEmails, {
  model: null,
  query: null,
  order: null,
  ascending: null,
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

  @computed("query")
  title(query) {
    return I18n.t("admin.users.titles." + query);
  },

  _filterUsers: debounce(function() {
    this.resetFilters();
  }, 250).observes("listFilter"),

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
      ascending: this.ascending,
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
