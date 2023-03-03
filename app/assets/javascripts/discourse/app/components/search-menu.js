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
import { isiPad } from "discourse/lib/utilities";
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
  _lastEnterTimestamp = null;
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

  //fullSearch() {
  //searchData.loading = false;
  //SearchHelper.cancel();
  //const url = this.fullSearchUrl();
  //if (url) {
  //this.sendWidgetEvent("linkClicked");
  //DiscourseURL.routeTo(url);
  //}
  //}

  @action
  updateInTopicContext(value) {
    this.inTopicContext = value;
  }

  @action
  focusSearchInput(element) {
    if (this.args.searchVisible) {
      element.focus();
      element.select();
    }
  }

  clearPMInboxContext() {
    this.inPMInboxContext = false;
    this.focusSearchInput();
  }

  setTopicContext() {
    this.inTopicContext = true;
    this.focusSearchInput();
  }

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

      this._activeSearch = searchForTerm(term, {
        typeFilter,
        fullSearchUrl,
        searchContext,
      });
      this._activeSearch
        .then((results) => {
          // we ensure the current search term is the one used
          // when starting the query
          if (results && this.term === this.term) {
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

  //keyDown(e) {
  //if (e.key === "Escape") {
  //this.sendWidgetAction("toggleSearchMenu");
  //document.querySelector("#search-button").focus();
  //e.preventDefault();
  //return false;
  //}

  //if (searchData.loading) {
  //return;
  //}

  //if (e.which === 65 [> a <]) {
  //if (document.activeElement?.classList.contains("search-link")) {
  //if (document.querySelector("#reply-control.open")) {
  //add a link and focus composer

  //this.appEvents.trigger(
  //"composer:insert-text",
  //document.activeElement.href,
  //{
  //ensureSpace: true,
  //}
  //);
  //this.appEvents.trigger("header:keyboard-trigger", { type: "search" });

  //e.preventDefault();
  //document.querySelector("#reply-control.open textarea").focus();
  //return false;
  //}
  //}
  //}

  //const up = e.key === "ArrowUp";
  //const down = e.key === "ArrowDown";
  //if (up || down) {
  //let focused = document.activeElement.closest(".search-menu")
  //? document.activeElement
  //: null;

  //if (!focused) {
  //return;
  //}

  //let links = document.querySelectorAll(".search-menu .results a");
  //let results = document.querySelectorAll(
  //".search-menu .results .search-link"
  //);

  //if (!results.length) {
  //return;
  //}

  //let prevResult;
  //let result;

  //links.forEach((item) => {
  //if (item.classList.contains("search-link")) {
  //prevResult = item;
  //}

  //if (item === focused) {
  //result = prevResult;
  //}
  //});

  //let index = -1;

  //if (result) {
  //index = Array.prototype.indexOf.call(results, result);
  //}

  //if (index === -1 && down) {
  //document.querySelector(".search-menu .results .search-link").focus();
  //} else if (index === 0 && up) {
  //document.querySelector(".search-menu input#search-term").focus();
  //} else if (index > -1) {
  //index += down ? 1 : -1;
  //if (index >= 0 && index < results.length) {
  //results[index].focus();
  //}
  //}

  //e.preventDefault();
  //return false;
  //}

  //const searchInput = document.querySelector("#search-term");
  //if (e.key === "Enter" && e.target === searchInput) {
  //const recentEnterHit =
  //this.state._lastEnterTimestamp &&
  //Date.now() - this.state._lastEnterTimestamp < SECOND_ENTER_MAX_DELAY;

  //same combination as key-enter-escape mixin
  //if (
  //e.ctrlKey ||
  //e.metaKey ||
  //(isiPad() && e.altKey) ||
  //(searchData.typeFilter !== DEFAULT_TYPE_FILTER && recentEnterHit)
  //) {
  //this.fullSearch();
  //} else {
  //searchData.typeFilter = null;
  //this.triggerSearch();
  //}
  //this.state._lastEnterTimestamp = Date.now();
  //}

  //if (e.target === searchInput && e.key === "Backspace") {
  //if (!searchInput.value) {
  //this.clearTopicContext();
  //this.clearPMInboxContext();
  //}
  //}
  //}

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
        this._debouncer = discourseDebounce(this, this.perform, this, 400);
      }
    }
  }

  moreOfType(type) {
    searchData.typeFilter = type;
    this.triggerSearch();
  }
}
