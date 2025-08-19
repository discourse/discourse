import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import AssistantItem from "discourse/components/search-menu/results/assistant-item";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";

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

  <template>
    {{#if this.currentUser.recent_searches}}
      <div class="search-menu-recent">
        <div class="heading">
          <h4>{{i18n "search.recent"}}</h4>
          <DButton
            @title="search.clear_recent"
            @icon="xmark"
            @action={{this.clearRecent}}
            class="btn-flat clear-recent-searches"
          />
        </div>

        {{#each this.currentUser.recent_searches as |slug|}}
          <AssistantItem
            @icon="clock-rotate-left"
            @label={{slug}}
            @slug={{slug}}
            @closeSearchMenu={{@closeSearchMenu}}
            @searchTermChanged={{@searchTermChanged}}
            @usage="recent-search"
            @concatSlug={{true}}
          />
        {{/each}}
      </div>
    {{/if}}
  </template>
}
