import { searchForTerm, isValidSearchTerm } from 'discourse/lib/search';
import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import DiscourseURL from 'discourse/lib/url';

const searchData = {
  loading: false,
  results: {},
  noResults: false,
  term: undefined,
  typeFilter: null,
  invalidTerm: false,
  selected: null
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
      searchData.invalidTerm = true;

      widget.scheduleRerender();
    } else {
      searchData.invalidTerm = false;
      this._activeSearch = searchForTerm(term, { typeFilter, searchContext, fullSearchUrl });
      this._activeSearch.then(content => {
        searchData.noResults = content.resultTypes.length === 0;

        if (content.grouped_search_result) {
          searchData.term = content.grouped_search_result.term;
        }

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

  fullSearchUrl(opts) {
    const contextEnabled = searchData.contextEnabled;

    const ctx = contextEnabled ? this.searchContext() : null;
    const type = ctx ? Ember.get(ctx, 'type') : null;

    if (contextEnabled && type === 'topic') {
      return;
    }

    let url = '/search';
    const params = [];

    if (searchData.term) {
      let query = '';

      query += `q=${encodeURIComponent(searchData.term)}`;

      if (contextEnabled && ctx) {
        if (this.currentUser &&
            ctx.id.toString().toLowerCase() === this.currentUser.username_lower &&
            type === "private_messages") {
          query += ' in:private';
        } else {
          query += encodeURIComponent(" " + type + ":" + ctx.id);
        }
      }

      if (query) params.push(query);
    }

    if (opts && opts.expanded) params.push('expanded=true');

    if (params.length > 0) {
      url = `${url}?${params.join("&")}`;
    }

    return Discourse.getURL(url);
  },

  panelContents() {
    const contextEnabled = searchData.contextEnabled;

    const results = [
      this.attach('search-term', { value: searchData.term, contextEnabled }),
      this.attach('search-context', {
        contextEnabled,
        url: this.fullSearchUrl({ expanded: true })
      })
    ];

    if (searchData.term) {
      if (searchData.loading) {
        results.push(h('div.searching', h('div.spinner')));
      } else {
        results.push(this.attach('search-menu-results', {
          term: searchData.term,
          noResults: searchData.noResults,
          results: searchData.results,
          invalidTerm: searchData.invalidTerm,
          searchContextEnabled: searchData.contextEnabled,
          selected: searchData.selected
        }));
      }
    }

    return results;
  },

  searchService() {
    if (!this._searchService) {
      this._searchService = this.register.lookup('search-service:main');
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
    if (searchData.contextEnabled !== attrs.contextEnabled) {
      searchData.contextEnabled = attrs.contextEnabled;
      this.triggerSearch();
    } else {
      searchData.contextEnabled = attrs.contextEnabled;
    }

    return this.attach('menu-panel', { maxWidth: 500, contents: () => this.panelContents() });
  },

  clickOutside() {
    this.sendWidgetAction('toggleSearchMenu');
  },

  keyDown(e) {
    if (searchData.loading || searchData.noResults) {
      return;
    }

    if (e.which === 13 /*enter*/ && searchData.selected) {
      searchData.selected = null;
      $('header .results li.selected a').click();
    }

    if (e.which === 38 /*arrow up*/ || e.which === 40 /*arrow down*/) {
      this.moveSelected(e.which === 38 ? -1 : 1);

      this.scheduleRerender();

      Em.run.next(()=>{
          if (searchData.selected) {

            // so we do not clear selected
            $('header .results li').off('blur');

            let selected = $('header .results li.selected')
              .focus()
              .on('blur', ()=> {
                searchData.selected = null;
                this.scheduleRerender();
                selected.off('blur');
              });

          } else {
            $('#search-term').focus();
          }
      });

      e.preventDefault();
      return false;
    }
  },

  moveSelected(offset) {

    if (offset === 1 && !searchData.selected) {
      searchData.selected = {type: searchData.results.resultTypes[0].type, index: 0};
      return;
    }

    if (!searchData.selected) {
      return;
    }

    let typeIndex = _.findIndex(searchData.results.resultTypes, item => item.type === searchData.selected.type);

    if (typeIndex === 0 && searchData.selected.index === 0 && offset === -1) {
      searchData.selected = null;
      return;
    }

    let currentResults = searchData.results.resultTypes[typeIndex].results;
    let newPosition = searchData.selected.index + offset;

    if (newPosition < currentResults.length && newPosition >= 0) {
      searchData.selected.index = newPosition;
    } else {
      // possibly move to next type
      let newTypeIndex = typeIndex + offset;
      if (newTypeIndex >= 0 && newTypeIndex < searchData.results.resultTypes.length) {
        newPosition = 0;
        if (offset === -1) {
          newPosition = searchData.results.resultTypes[newTypeIndex].results.length - 1;
        }
        searchData.selected = {type: searchData.results.resultTypes[newTypeIndex].type, index: newPosition};
      }
    }
  },

  triggerSearch() {
    searchData.noResults = false;
    this.searchService().set('highlightTerm', searchData.term);
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

    searchData.results = [];
    searchData.loading = false;
    SearchHelper.cancel();
    const url = this.fullSearchUrl();
    if (url) {
      this.sendWidgetEvent('linkClicked');
      DiscourseURL.routeTo(url);
    } else if (searchData.contextEnabled) {
      this.triggerSearch();
    }
  }
});
