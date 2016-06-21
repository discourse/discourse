import { searchForTerm, isValidSearchTerm } from 'discourse/lib/search';
import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import DiscourseURL from 'discourse/lib/url';

const searchData = {
  loading: false,
  results: {},
  noResults: false,
  term: undefined,
  typeFilter: null
};

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
    Ember.run.later(() => this._cancelSearch = false, 400);
  },

  perform(widget) {
    if (this._cancelSearch){
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
      widget.scheduleRerender();
    } else {
      this._activeSearch = searchForTerm(term, { typeFilter, searchContext, fullSearchUrl });
      this._activeSearch.then(content => {
        searchData.noResults = content.resultTypes.length === 0;
        searchData.results = content;
      }).finally(() => {
        searchData.loading = false;
        widget.scheduleRerender();
        this._activeSearch = null;
      });
    }
  }
};

export default createWidget('search-menu', {
  tagName: 'div.search-menu',

  fullSearchUrl() {
    const contextEnabled = searchData.contextEnabled;

    const ctx = contextEnabled ? this.searchContext() : null;
    const type = Ember.get(ctx, 'type');

    if (contextEnabled && type === 'topic') {
      return;
    }

    let url = '/search?q=' + encodeURIComponent(searchData.term);
    if (contextEnabled) {
      if (this.currentUser &&
          ctx.id.toString().toLowerCase() === this.currentUser.username_lower &&
          type === "private_messages") {
        url += ' in:private';
      } else {
        url += encodeURIComponent(" " + type + ":" + ctx.id);
      }
    }

    return Discourse.getURL(url);
  },

  panelContents() {
    const contextEnabled = searchData.contextEnabled;

    const results = [this.attach('search-term', { value: searchData.term, contextEnabled }),
                     this.attach('search-context', { contextEnabled })];

    if (searchData.loading) {
      results.push(h('div.searching', h('div.spinner')));
    } else {
      results.push(this.attach('search-menu-results', { term: searchData.term,
                                                        noResults: searchData.noResults,
                                                        results: searchData.results }));
    }

    return results;
  },

  searchService() {
    if (!this._searchService) {
      this._searchService = this.container.lookup('search-service:main');
    }
    return this._searchService;
  },

  searchContext() {
    if (!this._searchContext) {
      this._searchContext = this.searchService().get('searchContext');
    }
    return this._searchContext;
  },

  html(attrs) {
    searchData.contextEnabled = attrs.contextEnabled;

    return this.attach('menu-panel', { maxWidth: 500, contents: () => this.panelContents() });
  },

  clickOutside() {
    this.sendWidgetAction('toggleSearchMenu');
  },

  triggerSearch() {
    searchData.noResults = false;
    if (isValidSearchTerm(searchData.term)) {
      this.searchService().set('highlightTerm', searchData.term);
      searchData.loading = true;
      Ember.run.debounce(SearchHelper, SearchHelper.perform, this, 400);
    } else {
      searchData.results = [];
    }
  },

  moreOfType(type) {
    searchData.typeFilter = type;
    this.triggerSearch();
  },

  searchContextChanged(enabled) {
    searchData.typeFilter = null;
    this.sendWidgetAction('searchMenuContextChanged', enabled);
    searchData.contextEnabled = enabled;
    this.triggerSearch();
  },

  searchTermChanged(term) {
    searchData.typeFilter = null;
    searchData.term = term;
    this.triggerSearch();
  },

  fullSearch() {
    if (!isValidSearchTerm(searchData.term)) { return; }

    SearchHelper.cancel();
    const url = this.fullSearchUrl();
    if (url) {
      this.sendWidgetEvent('linkClicked');
      DiscourseURL.routeTo(url);
    }
  }
});
