(function() {

  window.Discourse.SearchView = Ember.View.extend(Discourse.Presence, {
    tagName: 'div',
    classNames: ['d-dropdown'],
    elementId: 'search-dropdown',
    templateName: 'search',
    didInsertElement: function() {
      /* Delegate ESC to the composer
      */

      var _this = this;
      return jQuery('body').on('keydown.search', function(e) {
        if (jQuery('#search-dropdown').is(':visible')) {
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
    searchPlaceholder: (function() {
      return Em.String.i18n("search.placeholder");
    }).property(),
    /* If we need to perform another search
    */

    newSearchNeeded: (function() {
      this.set('noResults', false);
      if (this.present('term')) {
        this.set('loading', true);
        this.searchTerm(this.get('term'), this.get('typeFilter'));
      } else {
        this.set('results', null);
      }
      return this.set('selectedIndex', 0);
    }).observes('term', 'typeFilter'),
    showCancelFilter: (function() {
      if (this.get('loading')) {
        return false;
      }
      return this.present('typeFilter');
    }).property('typeFilter', 'loading'),
    termChanged: (function() {
      return this.cancelType();
    }).observes('term'),

    // We can re-order them based on the context
    content: (function() {
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
    }).property('results'),
    
    updateProgress: (function() {
      var results;
      if (results = this.get('results')) {
        this.set('noResults', results.length === 0);
      }
      return this.set('loading', false);
    }).observes('results'),

    searchTerm: function(term, typeFilter) {
      var _this = this;
      if (this.currentSearch) {
        this.currentSearch.abort();
        this.currentSearch = null;
      }
      this.searcher = this.searcher || Discourse.debounce(function(term, typeFilter) {
        _this.currentSearch = jQuery.ajax({
          url: '/search',
          data: {
            term: term,
            type_filter: typeFilter
          },
          success: function(results) {
            return _this.set('results', results);
          }
        });
      }, 300);
      return this.searcher(term, typeFilter);
    },
    resultCount: (function() {
      var count;
      if (this.blank('content')) {
        return 0;
      }
      count = 0;
      this.get('content').each(function(result) {
        count += result.results.length;
      });
      return count;
    }).property('content'),
    moreOfType: function(type) {
      this.set('typeFilter', type);
      return false;
    },
    cancelType: function() {
      this.set('typeFilter', null);
      return false;
    },
    moveUp: function() {
      if (this.get('selectedIndex') === 0) {
        return;
      }
      return this.set('selectedIndex', this.get('selectedIndex') - 1);
    },
    moveDown: function() {
      if (this.get('resultCount') === (this.get('selectedIndex') + 1)) {
        return;
      }
      return this.set('selectedIndex', this.get('selectedIndex') + 1);
    },
    select: function() {
      var href;
      if (this.get('loading')) {
        return;
      }
      href = jQuery('#search-dropdown li.selected a').prop('href');
      if (href) {
        Discourse.routeTo(href);
      }
      return false;
    }
  });

}).call(this);
