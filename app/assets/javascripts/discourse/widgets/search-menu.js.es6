import { searchForTerm, isValidSearchTerm } from 'discourse/lib/search';
import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import DiscourseURL from 'discourse/lib/url';

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

    const { state } = widget;
    const { term, typeFilter, contextEnabled } = state;
    const searchContext = contextEnabled ? widget.searchContext() : null;
    const fullSearchUrl = widget.fullSearchUrl();

    if (!isValidSearchTerm(term)) {
      state.noResults = true;
      state.results = [];
      state.loading = false;
      widget.scheduleRerender();
    } else {
      this._activeSearch = searchForTerm(term, { typeFilter, searchContext, fullSearchUrl });
      this._activeSearch.then(content => {
        state.noResults = content.resultTypes.length === 0;
        state.results = content;
      }).finally(() => {
        state.loading = false;
        widget.scheduleRerender();
        this._activeSearch = null;
      });
    }
  }
};

export default createWidget('search-menu', {
  tagName: 'div.search-menu',
  buildKey: () => 'search-menu',

  defaultState() {
    return { loading: false,
             results: {},
             noResults: false,
             term: null,
             typeFilter: null };
  },

  fullSearchUrl() {
    const state = this.state;
    const contextEnabled = state.contextEnabled;

    const ctx = contextEnabled ? this.searchContext() : null;
    const type = Ember.get(ctx, 'type');

    if (contextEnabled && type === 'topic') {
      return;
    }

    let url = '/search?q=' + encodeURIComponent(state.term);
    if (contextEnabled) {
      if (ctx.id.toString().toLowerCase() === this.currentUser.username_lower &&
          type === "private_messages") {
        url += ' in:private';
      } else {
        url += encodeURIComponent(" " + type + ":" + ctx.id);
      }
    }

    return Discourse.getURL(url);
  },

  panelContents() {
    const { state } = this;
    const contextEnabled = state.contextEnabled;

    const results = [this.attach('search-term', { value: state.term, contextEnabled }),
                     this.attach('search-context', { contextEnabled })];

    if (state.loading) {
      results.push(h('div.searching', h('div.spinner')));
    } else {
      results.push(this.attach('search-menu-results', { term: state.term,
                                                        noResults: state.noResults,
                                                        results: state.results }));
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

  html(attrs, state) {
    state.contextEnabled = attrs.contextEnabled;

    return this.attach('menu-panel', { maxWidth: 500, contents: () => this.panelContents() });
  },

  clickOutside() {
    this.sendWidgetAction('toggleSearchMenu');
  },

  triggerSearch() {
    const { state } = this;

    state.noResults = false;
    if (isValidSearchTerm(state.term)) {
      this.searchService().set('highlightTerm', state.term);
      state.loading = true;
      Ember.run.debounce(SearchHelper, SearchHelper.perform, this, 400);
    } else {
      state.results = [];
    }
  },

  moreOfType(type) {
    this.state.typeFilter = type;
    this.triggerSearch();
  },

  searchContextChanged(enabled) {
    this.state.typeFilter = null;
    this.sendWidgetAction('searchMenuContextChanged', enabled);
    this.state.contextEnabled = enabled;
    this.triggerSearch();
  },

  searchTermChanged(term) {
    this.state.typeFilter = null;
    this.state.term = term;
    this.triggerSearch();
  },

  fullSearch() {
    if (!isValidSearchTerm(this.state.term)) { return; }

    SearchHelper.cancel();
    const url = this.fullSearchUrl();
    if (url) {
      this.sendWidgetEvent('linkClicked');
      DiscourseURL.routeTo(url);
    }
  }
});
