import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import User from "discourse/models/user";

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
  async clearRecent() {
    const result = await User.resetRecentSearches();
    if (result.success) {
      this.currentUser.recent_searches.clear();
    }
  }

  @action
  onKeyup(e) {
    if (e.key === "Escape") {
      this.args.closeSearchMenu();
      e.preventDefault();
      return false;
    }

    this.search.handleArrowUpOrDown(e);
  }

  async loadRecentSearches() {
    const result = await User.loadRecentSearches();
    if (result.success && result.recent_searches?.length) {
      this.currentUser.set("recent_searches", result.recent_searches);
    }
  }
}
