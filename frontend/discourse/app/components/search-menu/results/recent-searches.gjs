import Component from "@glimmer/component";
import { action, get } from "@ember/object";
import { service } from "@ember/service";
import AssistantItem from "discourse/components/search-menu/results/assistant-item";
import { MAX_RECENT_SEARCHES } from "discourse/lib/search";
import {
  applyBehaviorTransformer,
  applyValueTransformer,
} from "discourse/lib/transformer";
import User from "discourse/models/user";
import DButton from "discourse/ui-kit/d-button";

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

  // Entries rather than bare terms so a consumer can merge in history of its
  // own, and each row can say which kind of search it repeats.
  get entries() {
    // `get` rather than a native read: recent searches are set on the classic
    // user object, and a native read would not re-render when they arrive.
    const detailed = get(this.currentUser, "recent_searches_detailed");
    const terms = get(this.currentUser, "recent_searches") || [];
    const searches = (detailed || terms.map((term) => ({ term }))).map(
      (entry) => ({ ...entry, icon: "magnifying-glass" })
    );

    const merged = applyValueTransformer(
      "search-menu-recent-searches",
      searches,
      { location: this.args.location }
    );

    // one history, so entries order by when they happened rather than by which
    // list they came from; entries without a time keep to the back
    return [...merged]
      .sort((a, b) => (b.at || "").localeCompare(a.at || ""))
      .slice(0, MAX_RECENT_SEARCHES);
  }

  @action
  async clearRecent() {
    await applyBehaviorTransformer(
      "search-menu-clear-recent-searches",
      async () => {
        const result = await User.resetRecentSearches();
        if (result.success) {
          this.currentUser.set("recent_searches", []);
          this.currentUser.set("recent_searches_detailed", []);
        }
      },
      { location: this.args.location }
    );
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
      this.currentUser.set(
        "recent_searches_detailed",
        result.recent_searches_detailed
      );
    }
  }

  <template>
    {{#if this.entries}}
      <div class="search-menu-recent">
        {{#each this.entries as |entry|}}
          <AssistantItem
            @icon={{entry.icon}}
            @label={{entry.term}}
            @slug={{entry.term}}
            @closeSearchMenu={{@closeSearchMenu}}
            @searchTermChanged={{@searchTermChanged}}
            @usage={{if entry.usage entry.usage "recent-search"}}
            @concatSlug={{true}}
          />
        {{/each}}

        <DButton
          @label="search.clear_recent"
          @action={{this.clearRecent}}
          class="btn-transparent btn-small clear-recent-searches"
        />
      </div>
    {{/if}}
  </template>
}
