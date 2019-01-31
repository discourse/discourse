import { searchForTerm, isValidSearchTerm } from "discourse/lib/search";
import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import DiscourseURL from "discourse/lib/url";

const searchData = {};

export function initSearchData() {
  searchData.loading = false;
  searchData.results = {};
  searchData.noResults = false;
  searchData.term = undefined;
  searchData.typeFilter = null;
  searchData.invalidTerm = false;
  searchData.topicId = null;
}

initSearchData();

// Helps with debouncing and cancelling promises
const SearchHelper = {
  _activeSearch: null,
  _cancelSearch: null,

  // for cancelling debounced search
  cancel() {
    if (this._activeSearch) {
      this._activeSearch.abort();
    }

    this._cancelSearch = true;
    Ember.run.later(() => (this._cancelSearch = false), 400);
  },

  perform(widget) {
    if (this._cancelSearch) {
      this._cancelSearch = null;
      return;
    }

    if (this._activeSearch) {
      this._activeSearch.abort();
      this._activeSearch = null;
    }

    const { term, typeFilter, contextEnabled } = searchData;
    const searchContext = contextEnabled ? widget.searchContext() : null;
    const fullSearchUrl = widget.fullSearchUrl();

    if (!isValidSearchTerm(term)) {
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
        fullSearchUrl
      });
      this._activeSearch
        .then(content => {
          searchData.noResults = content.resultTypes.length === 0;

          if (content.grouped_search_result) {
            searchData.term = content.grouped_search_result.term;
          }

          searchData.results = content;

          if (searchContext && searchContext.type === "topic") {
            widget.appEvents.trigger("post-stream:refresh", { force: true });
            searchData.topicId = searchContext.id;
          } else {
            searchData.topicId = null;
          }
        })
        .finally(() => {
          searchData.loading = false;
          widget.scheduleRerender();
          this._activeSearch = null;
        });
    }
  }
};

export default createWidget("search-menu", {
  tagName: "div.search-menu",
  searchData,

  fullSearchUrl(opts) {
    const contextEnabled = searchData.contextEnabled;

    const ctx = contextEnabled ? this.searchContext() : null;
    const type = ctx ? Ember.get(ctx, "type") : null;

    let url = "/search";
    const params = [];

    if (searchData.term) {
      let query = "";

      query += `q=${encodeURIComponent(searchData.term)}`;

      if (contextEnabled && ctx) {
        if (
          this.currentUser &&
          ctx.id.toString().toLowerCase() ===
            this.currentUser.get("username_lower") &&
          type === "private_messages"
        ) {
          query += " in:private";
        } else {
          query += encodeURIComponent(" " + type + ":" + ctx.id);
        }
      }

      if (query) params.push(query);
    }

    if (opts && opts.expanded) params.push("expanded=true");

    if (params.length > 0) {
      url = `${url}?${params.join("&")}`;
    }

    return Discourse.getURL(url);
  },

  panelContents() {
    const contextEnabled = searchData.contextEnabled;

    let searchInput = [
      this.attach("search-term", { value: searchData.term, contextEnabled })
    ];
    if (searchData.term && searchData.loading) {
      searchInput.push(h("div.searching", h("div.spinner")));
    }

    const results = [
      h("div.search-input", searchInput),
      this.attach("search-context", {
        contextEnabled,
        url: this.fullSearchUrl({ expanded: true })
      })
    ];

    if (searchData.term && !searchData.loading) {
      results.push(
        this.attach("search-menu-results", {
          term: searchData.term,
          noResults: searchData.noResults,
          results: searchData.results,
          invalidTerm: searchData.invalidTerm,
          searchContextEnabled: searchData.contextEnabled
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
      contents: () => this.panelContents()
    });
  },

  clickOutside() {
    this.sendWidgetAction("toggleSearchMenu");
  },

  keyDown(e) {
    if (searchData.loading || searchData.noResults) {
      return;
    }

    if (e.which === 65 /* a */) {
      let focused = $("header .results .search-link:focus");
      if (focused.length === 1) {
        if ($("#reply-control.open").length === 1) {
          // add a link and focus composer

          this.appEvents.trigger("composer:insert-text", focused[0].href, {
            ensureSpace: true
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
      let focused = $("header .panel-body *:focus")[0];

      if (!focused) {
        return;
      }

      let links = $("header .panel-body .results a");
      let results = $("header .panel-body .results .search-link");

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
        $("header .panel-body .search-link:first").focus();
      } else if (index === 0 && up) {
        $("header .panel-body input:first").focus();
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
    Ember.run.debounce(SearchHelper, SearchHelper.perform, this, 400);
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

  fullSearch() {
    if (!isValidSearchTerm(searchData.term)) {
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
  }
});
