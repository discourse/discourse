import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";
import {
  isValidSearchTerm,
  searchForTerm,
  updateRecentSearches,
} from "discourse/lib/search";
import DiscourseURL from "discourse/lib/url";
import discourseDebounce from "discourse-common/lib/debounce";
import getURL from "discourse-common/lib/get-url";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { Promise } from "rsvp";
import { search as searchCategoryTag } from "discourse/lib/category-tag-search";
import userSearch from "discourse/lib/user-search";
import { CANCELLED_STATUS } from "discourse/lib/autocomplete";
import { cancel } from "@ember/runloop";
import I18n from "I18n";

const CATEGORY_SLUG_REGEXP = /(\#[a-zA-Z0-9\-:]*)$/gi;
const USERNAME_REGEXP = /(\@[a-zA-Z0-9\-\_]*)$/gi;
const SUGGESTIONS_REGEXP = /(in:|status:|order:|:)([a-zA-Z]*)$/gi;
const SECOND_ENTER_MAX_DELAY = 15000;
export const MODIFIER_REGEXP = /.*(\#|\@|:).*$/gi;
export const DEFAULT_TYPE_FILTER = "exclude_topics";

export default class SearchMenu extends Component {
  @service search;
  @service currentUser;
  @service siteSettings;
  @service appEvents;

  @tracked inTopicContext = this.args.inTopicContext;
  @tracked loading = false;
  @tracked results = {};
  @tracked noResults = false;
  @tracked term;
  @tracked inPMInboxContext =
    this.search?.searchContext?.type === "private_messages";
  @tracked typeFilter = DEFAULT_TYPE_FILTER;
  invalidTerm = false;
  suggestionResults = [];
  suggestionKeyword = false;
  _debouncer = null;
  _activeSearch = null;

  constructor() {
    super(...arguments);
  }

  @bind
  searchContext() {
    if (this.inTopicContext || this.inPMInboxContext) {
      return this.search.searchContext;
    }

    return false;
  }

  @bind
  fullSearchUrl(opts) {
    let url = "/search";
    const params = [];

    if (this.term) {
      let query = "";

      query += `q=${encodeURIComponent(this.term)}`;

      const searchContext = this.searchContext();
      if (searchContext?.type === "topic") {
        query += encodeURIComponent(` topic:${searchContext.id}`);
      } else if (searchContext?.type === "private_messages") {
        query += encodeURIComponent(` in:messages`);
      }

      if (query) {
        params.push(query);
      }
    }

    if (opts && opts.expanded) {
      params.push("expanded=true");
    }

    if (params.length > 0) {
      url = `${url}?${params.join("&")}`;
    }

    return getURL(url);
  }

  @bind
  clearSearch(e) {
    e.preventDefault();

    this.term = "";
    const searchInput = document.getElementById("search-term");
    searchInput.value = "";
    searchInput.focus();
    this.triggerSearch();
  }

  @action
  searchTermChanged(term, opts = {}) {
    this.typeFilter = opts.searchTopics ? null : DEFAULT_TYPE_FILTER;
    this.term = term;
    this.triggerSearch();
  }

  triggerAutocomplete(opts = {}) {
    if (opts.setTopicContext) {
      this.sendWidgetAction("setTopicContext");
      this.state.inTopicContext = true;
    }
    this.searchTermChanged(opts.value, { searchTopics: opts.searchTopics });
  }

  @action
  fullSearch() {
    this.loading = false;
    const url = this.fullSearchUrl();
    if (url) {
      this.sendWidgetEvent("linkClicked");
      DiscourseURL.routeTo(url);
    }
  }

  @action
  updateInTopicContext(value) {
    this.inTopicContext = value;
  }

  @action
  updateTypeFilter(value) {
    this.typeFilter = value;
  }

  @action
  focusSearchInput(element) {
    if (this.args.searchVisible) {
      element.focus();
      element.select();
    }
  }

  @action
  clearPMInboxContext() {
    this.inPMInboxContext = false;
    this.focusSearchInput();
  }

  @action
  setTopicContext() {
    this.inTopicContext = true;
    this.focusSearchInput();
  }

  @action
  clearTopicContext() {
    this.inTopicContext = false;
    this.focusSearchInput();
  }

  // for cancelling debounced search
  cancel() {
    if (this._activeSearch) {
      this._activeSearch.abort();
      this._activeSearch = null;
    }
  }

  perform() {
    this.cancel();

    const searchContext = this.searchContext();
    const fullSearchUrl = this.fullSearchUrl();
    const matchSuggestions = this.matchesSuggestions();

    if (matchSuggestions) {
      this.noResults = true;
      this.results = {};
      this.loading = false;
      this.suggestionResults = [];

      if (matchSuggestions.type === "category") {
        const categorySearchTerm = matchSuggestions.categoriesMatch[0].replace(
          "#",
          ""
        );

        const categoryTagSearch = searchCategoryTag(
          categorySearchTerm,
          this.siteSettings
        );
        Promise.resolve(categoryTagSearch).then((results) => {
          if (results !== CANCELLED_STATUS) {
            this.suggestionResults = results;
            this.suggestionKeyword = "#";
          }
        });
      } else if (matchSuggestions.type === "username") {
        const userSearchTerm = matchSuggestions.usernamesMatch[0].replace(
          "@",
          ""
        );
        const opts = { includeGroups: true, limit: 6 };
        if (userSearchTerm.length > 0) {
          opts.term = userSearchTerm;
        } else {
          opts.lastSeenUsers = true;
        }

        userSearch(opts).then((result) => {
          if (result?.users?.length > 0) {
            this.suggestionResults = result.users;
            this.suggestionKeyword = "@";
          } else {
            this.noResults = true;
            this.suggestionKeyword = false;
          }
        });
      } else {
        this.suggestionKeyword = matchSuggestions[0];
      }
      return;
    }

    this.suggestionKeyword = false;

    if (!this.term) {
      this.noResults = false;
      this.results = {};
      this.loading = false;
      this.invalidTerm = false;
    } else if (!isValidSearchTerm(this.term, this.siteSettings)) {
      this.noResults = true;
      this.results = {};
      this.loading = false;
      this.invalidTerm = true;
    } else {
      this.invalidTerm = false;

      this._activeSearch = searchForTerm(this.term, {
        typeFilter: this.typeFilter,
        fullSearchUrl: this.fullSearchUrl,
        searchContext,
      });
      this._activeSearch
        .then((results) => {
          // we ensure the current search term is the one used
          // when starting the query
          if (results) {
            if (searchContext) {
              this.appEvents.trigger("post-stream:refresh", {
                force: true,
              });
            }

            this.noResults = results.resultTypes.length === 0;
            this.results = results;
          }
        })
        .catch(popupAjaxError)
        .finally(() => {
          this.loading = false;
        });
    }
  }

  matchesSuggestions() {
    if (this.term === undefined || this.includesTopics()) {
      return false;
    }

    const term = this.term.trim();
    const categoriesMatch = term.match(CATEGORY_SLUG_REGEXP);

    if (categoriesMatch) {
      return { type: "category", categoriesMatch };
    }

    const usernamesMatch = term.match(USERNAME_REGEXP);
    if (usernamesMatch) {
      return { type: "username", usernamesMatch };
    }

    const suggestionsMatch = term.match(SUGGESTIONS_REGEXP);
    if (suggestionsMatch) {
      return suggestionsMatch;
    }

    return false;
  }

  includesTopics() {
    return this.typeFilter !== DEFAULT_TYPE_FILTER;
  }

  //mouseDownOutside() {
  //this.sendWidgetAction("toggleSearchMenu");
  //}

  @action
  triggerSearch() {
    this.noResults = false;
    if (this.includesTopics()) {
      if (this.inTopicContext) {
        this.search.set("highlightTerm", this.term);
      }

      this.loading = true;
      cancel(this._debouncer);
      this.perform();

      if (this.currentUser) {
        updateRecentSearches(this.currentUser, this.term);
      }
    } else {
      this.loading = false;
      if (!this.inTopicContext) {
        this._debouncer = discourseDebounce(this, this.perform, 400);
      }
    }
  }

  moreOfType(type) {
    searchData.typeFilter = type;
    this.triggerSearch();
  }
}
