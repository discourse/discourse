import { isValidSearchTerm, searchForTerm } from "discourse/lib/search";
import DiscourseURL from "discourse/lib/url";
import { createWidget } from "discourse/widgets/widget";
import discourseDebounce from "discourse-common/lib/debounce";
import { get } from "@ember/object";
import getURL from "discourse-common/lib/get-url";
import { h } from "virtual-dom";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { Promise } from "rsvp";
import { search as searchCategoryTag } from "discourse/lib/category-tag-search";
import userSearch from "discourse/lib/user-search";
import { CANCELLED_STATUS } from "discourse/lib/autocomplete";

const CATEGORY_SLUG_REGEXP = /(\#[a-zA-Z0-9\-:]*)$/gi;
const USERNAME_REGEXP = /(\@[a-zA-Z0-9\-\_]*)$/gi;
const SUGGESTIONS_REGEXP = /(in:|status:|order:|:)([a-zA-Z]*)$/gi;

const searchData = {};

export function initSearchData() {
  searchData.loading = false;
  searchData.results = {};
  searchData.noResults = false;
  searchData.term = undefined;
  searchData.typeFilter = null;
  searchData.invalidTerm = false;
  searchData.topicId = null;
  searchData.afterAutocomplete = false;
  searchData.suggestionResults = [];
}

initSearchData();

// Helps with debouncing and cancelling promises
const SearchHelper = {
  _activeSearch: null,

  // for cancelling debounced search
  cancel() {
    if (this._activeSearch) {
      this._activeSearch.abort();
      this._activeSearch = null;
    }
  },

  perform(widget) {
    this.cancel();

    const { term, typeFilter, contextEnabled } = searchData;
    const searchContext = contextEnabled ? widget.searchContext() : null;
    const fullSearchUrl = widget.fullSearchUrl();
    const matchSuggestions = this.matchesSuggestions();

    if (matchSuggestions) {
      searchData.noResults = true;
      searchData.results = {};
      searchData.loading = false;
      searchData.suggestionResults = [];

      if (matchSuggestions.type === "category") {
        const categorySearchTerm = matchSuggestions.categoriesMatch[0].replace(
          "#",
          ""
        );

        const categoryTagSearch = searchCategoryTag(
          categorySearchTerm,
          widget.siteSettings
        );
        Promise.resolve(categoryTagSearch).then((results) => {
          if (results !== CANCELLED_STATUS) {
            searchData.suggestionResults = results;
            searchData.suggestionKeyword = "#";
          }
          widget.scheduleRerender();
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
            searchData.suggestionResults = result.users;
            searchData.suggestionKeyword = "@";
          } else {
            searchData.noResults = true;
            searchData.suggestionKeyword = false;
          }
          widget.scheduleRerender();
        });
      } else {
        searchData.suggestionKeyword = matchSuggestions[0];
        widget.scheduleRerender();
      }
      return;
    }

    searchData.suggestionKeyword = false;

    if (!isValidSearchTerm(term, widget.siteSettings)) {
      searchData.noResults = true;
      searchData.results = [];
      searchData.loading = false;
      searchData.invalidTerm = true;

      widget.scheduleRerender();
    } else {
      searchData.invalidTerm = false;
      this._activeSearch = searchForTerm(term, {
        typeFilter,
        searchContext,
        fullSearchUrl,
      });
      this._activeSearch
        .then((results) => {
          // we ensure the current search term is the one used
          // when starting the query
          if (results && term === searchData.term) {
            searchData.noResults = results.resultTypes.length === 0;
            searchData.results = results;

            if (searchContext && searchContext.type === "topic") {
              widget.appEvents.trigger("post-stream:refresh", { force: true });
              searchData.topicId = searchContext.id;
            } else {
              searchData.topicId = null;
            }
          }
        })
        .catch(popupAjaxError)
        .finally(() => {
          searchData.loading = false;
          searchData.afterAutocomplete = false;
          widget.scheduleRerender();
        });
    }
  },

  matchesSuggestions() {
    if (searchData.term === undefined) {
      return false;
    }

    const categoriesMatch = searchData.term.match(CATEGORY_SLUG_REGEXP);

    if (categoriesMatch) {
      return { type: "category", categoriesMatch };
    }

    const usernamesMatch = searchData.term.match(USERNAME_REGEXP);
    if (usernamesMatch) {
      return { type: "username", usernamesMatch };
    }

    const suggestionsMatch = searchData.term.match(SUGGESTIONS_REGEXP);
    if (suggestionsMatch) {
      return suggestionsMatch;
    }

    return false;
  },
};

export default createWidget("search-menu", {
  tagName: "div.search-menu",
  searchData,

  fullSearchUrl(opts) {
    const contextEnabled = searchData.contextEnabled;

    const ctx = contextEnabled ? this.searchContext() : null;
    const type = ctx ? get(ctx, "type") : null;

    let url = "/search";
    const params = [];

    if (searchData.term) {
      let query = "";

      query += `q=${encodeURIComponent(searchData.term)}`;

      if (contextEnabled && ctx) {
        if (type === "private_messages") {
          if (
            this.currentUser &&
            ctx.id.toString().toLowerCase() ===
              this.currentUser.get("username_lower")
          ) {
            query += " in:personal";
          } else {
            query += encodeURIComponent(
              ` personal_messages:${ctx.id.toString().toLowerCase()}`
            );
          }
        } else {
          query += encodeURIComponent(" " + type + ":" + ctx.id);
        }
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
  },

  panelContents() {
    const { contextEnabled, afterAutocomplete } = searchData;

    let searchInput = [
      this.attach(
        "search-term",
        { value: searchData.term, contextEnabled },
        { state: { afterAutocomplete } }
      ),
    ];
    if (searchData.term && searchData.loading) {
      searchInput.push(h("div.searching", h("div.spinner")));
    }

    const results = [
      h("div.search-input", searchInput),
      this.attach("search-context", {
        contextEnabled,
        url: this.fullSearchUrl({ expanded: true }),
      }),
    ];

    if (searchData.term && !searchData.loading) {
      results.push(
        this.attach("search-menu-results", {
          term: searchData.term,
          noResults: searchData.noResults,
          results: searchData.results,
          invalidTerm: searchData.invalidTerm,
          searchContextEnabled: searchData.contextEnabled,
          suggestionKeyword: searchData.suggestionKeyword,
          suggestionResults: searchData.suggestionResults,
        })
      );
    }

    return results;
  },

  searchService() {
    if (!this._searchService) {
      this._searchService = this.register.lookup("search-service:main");
    }
    return this._searchService;
  },

  searchContext() {
    if (!this._searchContext) {
      this._searchContext = this.searchService().get("searchContext");
    }
    return this._searchContext;
  },

  html(attrs) {
    const searchContext = this.searchContext();

    const shouldTriggerSearch =
      searchData.contextEnabled !== attrs.contextEnabled ||
      (searchContext &&
        searchContext.type === "topic" &&
        searchData.topicId !== null &&
        searchData.topicId !== searchContext.id);

    if (shouldTriggerSearch && searchData.term) {
      this.triggerSearch();
    }

    searchData.contextEnabled = attrs.contextEnabled;

    return this.attach("menu-panel", {
      maxWidth: 500,
      contents: () => this.panelContents(),
    });
  },

  clickOutside() {
    this.sendWidgetAction("toggleSearchMenu");
  },

  keyDown(e) {
    if (e.which === 27 /* escape */) {
      this.sendWidgetAction("toggleSearchMenu");
      e.preventDefault();
      return false;
    }

    if (searchData.loading) {
      return;
    }

    if (e.which === 65 /* a */) {
      let focused = $("header .results .search-link:focus");
      if (focused.length === 1) {
        if ($("#reply-control.open").length === 1) {
          // add a link and focus composer

          this.appEvents.trigger("composer:insert-text", focused[0].href, {
            ensureSpace: true,
          });
          this.appEvents.trigger("header:keyboard-trigger", { type: "search" });

          e.preventDefault();
          $("#reply-control.open textarea").focus();
          return false;
        }
      }
    }

    const up = e.which === 38;
    const down = e.which === 40;
    if (up || down) {
      let focused = $(".search-menu *:focus")[0];

      if (!focused) {
        return;
      }

      let links = $(".search-menu .results a");
      let results = $(".search-menu .results .search-link");

      let prevResult;
      let result;

      links.each((idx, item) => {
        if ($(item).hasClass("search-link")) {
          prevResult = item;
        }

        if (item === focused) {
          result = prevResult;
        }
      });

      let index = -1;

      if (result) {
        index = results.index(result);
      }

      if (index === -1 && down) {
        $(".search-menu .search-link:first").focus();
      } else if (index === 0 && up) {
        $(".search-menu input:first").focus();
      } else if (index > -1) {
        index += down ? 1 : -1;
        if (index >= 0 && index < results.length) {
          $(results[index]).focus();
        }
      }

      e.preventDefault();
      return false;
    }
  },

  triggerSearch() {
    searchData.noResults = false;
    this.searchService().set("highlightTerm", searchData.term);
    searchData.loading = true;
    discourseDebounce(SearchHelper, SearchHelper.perform, this, 400);
  },

  moreOfType(type) {
    searchData.typeFilter = type;
    this.triggerSearch();
  },

  searchContextChanged(enabled) {
    // This indicates the checkbox has been clicked, NOT that the context has changed.
    searchData.typeFilter = null;
    this.sendWidgetAction("searchMenuContextChanged", enabled);
    searchData.contextEnabled = enabled;
    this.triggerSearch();
  },

  searchTermChanged(term) {
    searchData.typeFilter = null;
    searchData.term = term;
    this.triggerSearch();
  },

  triggerAutocomplete(term) {
    searchData.afterAutocomplete = true;
    this.searchTermChanged(term);
  },

  fullSearch() {
    if (!isValidSearchTerm(searchData.term, this.siteSettings)) {
      return;
    }

    searchData.results = [];
    searchData.loading = false;
    SearchHelper.cancel();
    const url = this.fullSearchUrl();
    if (url) {
      this.sendWidgetEvent("linkClicked");
      DiscourseURL.routeTo(url);
    }
  },
});
