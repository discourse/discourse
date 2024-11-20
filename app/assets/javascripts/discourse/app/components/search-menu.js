import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { Promise } from "rsvp";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { CANCELLED_STATUS } from "discourse/lib/autocomplete";
import { search as searchCategoryTag } from "discourse/lib/category-tag-search";
import {
  isValidSearchTerm,
  searchForTerm,
  updateRecentSearches,
} from "discourse/lib/search";
import DiscourseURL from "discourse/lib/url";
import userSearch from "discourse/lib/user-search";
import discourseDebounce from "discourse-common/lib/debounce";
import getURL from "discourse-common/lib/get-url";
import { bind } from "discourse-common/utils/decorators";

const CATEGORY_SLUG_REGEXP = /(\#[a-zA-Z0-9\-:]*)$/gi;
const USERNAME_REGEXP = /(\@[a-zA-Z0-9\-\_]*)$/gi;
const SUGGESTIONS_REGEXP = /(in:|status:|order:|:)([a-zA-Z]*)$/gi;
export const SEARCH_INPUT_ID = "search-term";
export const MODIFIER_REGEXP = /.*(\#|\@|:).*$/gi;
export const DEFAULT_TYPE_FILTER = "exclude_topics";

export function focusSearchInput() {
  document.getElementById(SEARCH_INPUT_ID).focus();
}

export default class SearchMenu extends Component {
  @service search;
  @service currentUser;
  @service siteSettings;
  @service appEvents;

  @tracked loading = false;
  @tracked
  inPMInboxContext = this.search.searchContext?.type === "private_messages";
  @tracked typeFilter = DEFAULT_TYPE_FILTER;
  @tracked suggestionKeyword = false;
  @tracked suggestionResults = [];
  @tracked invalidTerm = false;
  @tracked menuPanelOpen = false;

  _debouncer = null;
  _activeSearch = null;

  @bind
  setupEventListeners() {
    // We only need to register click events when the search menu is rendered outside of the header.
    // The header handles clicking outside.
    if (!this.args.inlineResults) {
      document.addEventListener("mousedown", this.onDocumentPress);
      document.addEventListener("touchend", this.onDocumentPress);
    }
  }

  willDestroy() {
    if (!this.args.inlineResults) {
      document.removeEventListener("mousedown", this.onDocumentPress);
      document.removeEventListener("touchend", this.onDocumentPress);
    }
    super.willDestroy(...arguments);
  }

  @bind
  onDocumentPress(event) {
    if (!this.menuPanelOpen) {
      return;
    }

    if (!event.target.closest(".search-menu-container.menu-panel-results")) {
      this.close();
    }
  }

  get classNames() {
    const classes = ["search-menu-container"];

    if (!this.args.inlineResults) {
      classes.push("menu-panel-results");
    }

    if (this.loading) {
      classes.push("loading");
    }

    return classes.join(" ");
  }

  get includesTopics() {
    return (
      !!this.search.results?.topics?.length ||
      this.typeFilter !== DEFAULT_TYPE_FILTER
    );
  }

  get searchContext() {
    if (this.search.inTopicContext || this.inPMInboxContext) {
      return this.search.searchContext;
    }

    return false;
  }

  @action
  onKeydown(event) {
    if (event.key === "Escape") {
      this.close();
    }
  }

  @action
  close() {
    if (this.args?.onClose) {
      return this.args.onClose();
    }

    // We want to blur the search input when in stand-alone mode
    // so that when we focus on the search input again, the menu panel pops up
    document.getElementById(SEARCH_INPUT_ID)?.blur();
    this.menuPanelOpen = false;
  }

  @action
  open() {
    this.menuPanelOpen = true;
  }

  @bind
  fullSearchUrl(opts) {
    let url = "/search";
    let params = new URLSearchParams();

    if (this.search.activeGlobalSearchTerm) {
      let q = this.search.activeGlobalSearchTerm;

      if (this.searchContext?.type === "topic") {
        q += ` topic:${this.searchContext.id}`;
      } else if (this.searchContext?.type === "private_messages") {
        q += " in:messages";
      }
      params.set("q", q);
    }
    if (opts?.expanded) {
      params.set("expanded", "true");
    }
    if (params.toString() !== "") {
      url = `${url}?${params}`;
    }
    return getURL(url);
  }

  @action
  openAdvancedSearch() {
    this.fullSearch();
    this.close();
  }

  get displayMenuPanelResults() {
    if (this.args.inlineResults) {
      return false;
    }

    return this.menuPanelOpen;
  }

  @bind
  clearSearch(e) {
    e.stopPropagation();
    e.preventDefault();
    this.search.activeGlobalSearchTerm = "";
    focusSearchInput();
    this.triggerSearch();
  }

  @action
  searchTermChanged(term, opts = {}) {
    this.typeFilter = opts.searchTopics ? null : DEFAULT_TYPE_FILTER;
    if (opts.setTopicContext) {
      this.search.inTopicContext = true;
    }
    this.search.activeGlobalSearchTerm = term;
    this.triggerSearch();
  }

  @action
  fullSearch() {
    this.loading = false;
    const url = this.fullSearchUrl();
    if (url) {
      DiscourseURL.routeTo(url);
    }
  }

  @action
  updateTypeFilter(value) {
    this.typeFilter = value;
  }

  @action
  clearPMInboxContext() {
    this.inPMInboxContext = false;
  }

  @action
  clearTopicContext() {
    this.search.inTopicContext = false;
  }

  // for cancelling debounced search
  cancel() {
    if (this._activeSearch) {
      this._activeSearch.abort();
      this._activeSearch = null;
    }
  }

  async perform() {
    this.cancel();

    const matchSuggestions = this.matchesSuggestions();
    if (matchSuggestions) {
      this.search.noResults = true;
      this.search.results = {};
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
            this.search.noResults = true;
            this.suggestionKeyword = false;
          }
        });
      } else {
        this.suggestionKeyword = matchSuggestions[0];
      }
      return;
    }

    this.suggestionKeyword = false;

    if (!this.search.activeGlobalSearchTerm) {
      this.search.noResults = false;
      this.search.results = {};
      this.loading = false;
      this.invalidTerm = false;
    } else if (
      !isValidSearchTerm(this.search.activeGlobalSearchTerm, this.siteSettings)
    ) {
      this.search.noResults = true;
      this.search.results = {};
      this.loading = false;
      this.invalidTerm = true;
    } else {
      this.loading = true;
      this.invalidTerm = false;

      this._activeSearch = searchForTerm(this.search.activeGlobalSearchTerm, {
        typeFilter: this.typeFilter,
        fullSearchUrl: this.fullSearchUrl,
        searchContext: this.searchContext,
      });

      this._activeSearch
        .then((results) => {
          // we ensure the current search term is the one used
          // when starting the query
          if (results) {
            if (this.searchContext) {
              this.appEvents.trigger("post-stream:refresh", {
                force: true,
              });
            }

            this.search.noResults = results.resultTypes.length === 0;
            this.search.results = results;
          }
        })
        .catch(popupAjaxError)
        .finally(() => {
          this.loading = false;
        });
    }
  }

  matchesSuggestions() {
    if (
      this.search.activeGlobalSearchTerm === undefined ||
      this.includesTopics
    ) {
      return false;
    }

    const term = this.search.activeGlobalSearchTerm.trim();
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

  @action
  triggerSearch() {
    this.search.noResults = false;

    if (this.includesTopics) {
      if (this.search.contextType === "topic") {
        this.search.highlightTerm = this.search.activeGlobalSearchTerm;
      }
      this.loading = true;
      cancel(this._debouncer);
      this.perform();

      if (this.currentUser) {
        updateRecentSearches(
          this.currentUser,
          this.search.activeGlobalSearchTerm
        );
      }
    } else {
      this.loading = false;
      if (!this.search.inTopicContext) {
        this._debouncer = discourseDebounce(this, this.perform, 400);
      }
    }
  }
}
