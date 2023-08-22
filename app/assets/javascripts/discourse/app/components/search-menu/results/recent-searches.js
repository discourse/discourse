import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import User from "discourse/models/user";
import { action } from "@ember/object";
import { focusSearchButton } from "discourse/components/search-menu";

export default class RecentSearches extends Component {
  @service currentUser;
  @service siteSettings;

  constructor() {
    super(...arguments);

    if (
      this.currentUser &&
      this.siteSettings.log_search_queries &&
      !this.currentUser.recent_searches?.length
    ) {
      this.loadRecentSearches();
    }
  }

  @action
  clearRecent() {
    return User.resetRecentSearches().then((result) => {
      if (result.success) {
        this.currentUser.recent_searches.clear();
      }
    });
  }

  @action
  onKeyup(e) {
    if (e.key === "Escape") {
      focusSearchButton();
      this.args.closeSearchMenu();
      e.preventDefault();
      return false;
    }

    this.search.handleArrowUpOrDown(e);
  }

  loadRecentSearches() {
    User.loadRecentSearches().then((result) => {
      if (result.success && result.recent_searches?.length) {
        this.currentUser.set("recent_searches", result.recent_searches);
      }
    });
  }
}
