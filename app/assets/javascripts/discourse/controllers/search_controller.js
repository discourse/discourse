/**
  Support for searching

  @class SearchController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.SearchController = Em.ArrayController.extend(Discourse.Presence, {

  // If we need to perform another search
  newSearchNeeded: function() {
    this.set('noResults', false);
    var term = this.get('term');
    if (term && term.length >= Discourse.SiteSettings.min_search_term_length) {
      this.set('loading', true);
      this.searchTerm(term, this.get('typeFilter'));
    } else {
      this.set('content', Em.A());
    }
    this.set('selectedIndex', 0);
  }.observes('term', 'typeFilter'),

  searchTerm: Discourse.debouncePromise(function(term, typeFilter) {
    var searchController = this;
    this.set('count', 0);

    var searcher = Discourse.Search.forTerm(term, {
      typeFilter: typeFilter,
      searchContext: searchController.get('searchContext')
    });

    return searcher.then(function(results) {
      searchController.set('results', results);
      if (results) {
        searchController.set('noResults', results.length === 0);

        // Make it easy to find the results by type
        var results_hashed = {};
        results.forEach(function(r) { results_hashed[r.type] = r });

        // Default order
        var order = ['topic', 'category', 'user'];
        results = order.map(function(o) { return results_hashed[o] }).without(void 0);

        var index = 0;
        results.forEach(function(r) {
          r.results.each(function(item) {
            item.index = index++;
          });
        });
        searchController.set('count', index);
        searchController.set('content', results);
      }

      searchController.set('loading', false);
    });
  }, 300),

  showCancelFilter: function() {
    if (this.get('loading')) return false;
    return this.present('typeFilter');
  }.property('typeFilter', 'loading'),

  termChanged: function() {
    this.cancelType();
  }.observes('term'),

  moreOfType: function(type) {
    this.set('typeFilter', type);
  },

  cancelType: function() {
    this.set('typeFilter', null);
  },

  moveUp: function() {
    if (this.get('selectedIndex') === 0) return;
    this.set('selectedIndex', this.get('selectedIndex') - 1);
  },

  moveDown: function() {
    if (this.get('resultCount') === (this.get('selectedIndex') + 1)) return;
    this.set('selectedIndex', this.get('selectedIndex') + 1);
  },

  select: function() {
    if (this.get('loading')) return;
    var href = $('#search-dropdown li.selected a').prop('href');
    if (href) {
      Discourse.URL.routeTo(href);
    }
  }

});