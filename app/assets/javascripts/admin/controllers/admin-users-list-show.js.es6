import debounce from "discourse/lib/debounce";
import { i18n } from "discourse/lib/computed";
import AdminUser from "admin/models/admin-user";
import CanCheckEmails from "discourse/mixins/can-check-emails";
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend(CanCheckEmails, {
  model: null,
  query: null,
  order: null,
  ascending: null,
  showEmails: false,
  refreshing: false,
  listFilter: null,
  selectAll: false,
  searchHint: i18n("search_hint"),

  @computed("query")
  title(query) {
    return I18n.t("admin.users.titles." + query);
  },

  _filterUsers: debounce(function() {
    this._refreshUsers();
  }, 250).observes("listFilter"),

  _refreshUsers() {
    this.set("refreshing", true);

    AdminUser.findAll(this.get("query"), {
      filter: this.get("listFilter"),
      show_emails: this.get("showEmails"),
      order: this.get("order"),
      ascending: this.get("ascending")
    })
      .then(result => this.set("model", result))
      .finally(() => this.set("refreshing", false));
  },

  actions: {
    toggleEmailVisibility() {
      this.toggleProperty("showEmails");
      this._refreshUsers();
    }
  }
});
