/**
  This view handles search facilities of Discourse

  @class SearchView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.SearchView = Discourse.View.extend({
  tagName: 'div',
  classNames: ['d-dropdown'],
  elementId: 'search-dropdown',
  templateName: 'search',

  didInsertElement: function() {
    // Delegate ESC to the composer
    var _this = this;
    return $('body').on('keydown.search', function(e) {
      if ($('#search-dropdown').is(':visible')) {
        switch (e.which) {
          case 13:
            return _this.select();
          case 38:
            return _this.moveUp();
          case 40:
            return _this.moveDown();
        }
      }
    });
  },

  searchPlaceholder: function() {
    return Em.String.i18n("search.placeholder");
  }.property(),

  // If we need to perform another search
  newSearchNeeded: function() {
    this.set('noResults', false);
    var term = this.get('term');
    if (term && term.length >= Discourse.SiteSettings.min_search_term_length) {
      this.set('loading', true);
      this.searchTerm(term, this.get('typeFilter'));
    } else {
      this.set('results', null);
    }
    return this.set('selectedIndex', 0);
  }.observes('term', 'typeFilter'),

  searchTerm: Discourse.debouncePromise(function(term, typeFilter) {
    var searchView = this;
    return Discourse.Search.forTerm(term, typeFilter).then(function(results) {
      searchView.set('results', results);
    });
  }, 300),

  showCancelFilter: function() {
    if (this.get('loading')) return false;
    return this.present('typeFilter');
  }.property('typeFilter', 'loading'),

  termChanged: function() {
    return this.cancelType();
  }.observes('term'),

  // We can re-order them based on the context
  content: function() {
    var index, order, path, results, results_hashed;
    if (results = this.get('results')) {
      // Make it easy to find the results by type
      results_hashed = {};
      results.each(function(r) {
        results_hashed[r.type] = r;
      });
      path = Discourse.get('router.currentState.path');
      // Default order
      order = ['topic', 'category', 'user'];
      results = (order.map(function(o) {
        return results_hashed[o];
      })).without(void 0);
      index = 0;
      results.each(function(result) {
        return result.results.each(function(item) {
          item.index = index++;
        });
      });
    }
    return results;
  }.property('results'),

  updateProgress: function() {
    var results;
    if (results = this.get('results')) {
      this.set('noResults', results.length === 0);
    }
    return this.set('loading', false);
  }.observes('results'),

  resultCount: function() {
    var count;
    if (this.blank('content')) return 0;
    count = 0;
    this.get('content').each(function(result) {
      count += result.results.length;
    });
    return count;
  }.property('content'),

  moreOfType: function(type) {
    this.set('typeFilter', type);
    return false;
  },

  cancelType: function() {
    this.set('typeFilter', null);
    return false;
  },

  moveUp: function() {
    if (this.get('selectedIndex') === 0) return;
    return this.set('selectedIndex', this.get('selectedIndex') - 1);
  },

  moveDown: function() {
    if (this.get('resultCount') === (this.get('selectedIndex') + 1)) return;
    return this.set('selectedIndex', this.get('selectedIndex') + 1);
  },

  select: function() {
    if (this.get('loading')) return;
    var href = $('#search-dropdown li.selected a').prop('href');
    if (href) {
      Discourse.URL.routeTo(href);
    }
    return false;
  }
});


