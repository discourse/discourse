/**
  Support for searching

  @class SearchController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
export default Em.ArrayController.extend(Discourse.Presence, {

  contextChanged: function(){
    this.setProperties({ term: "", content: [], resultCount: 0, urls: [] });
  }.observes("searchContext"),

  // If we need to perform another search
  newSearchNeeded: function() {
    this.set('noResults', false);
    var term = (this.get('term') || '').trim();
    if (term.length >= Discourse.SiteSettings.min_search_term_length) {
      this.set('loading', true);
      this.searchTerm(term, this.get('typeFilter'));
    } else {
      this.setProperties({ content: [], resultCount: 0, urls: [] });
    }
    this.set('selectedIndex', 0);
  }.observes('term', 'typeFilter'),

  searchTerm: Discourse.debouncePromise(function(term, typeFilter) {
    var self = this;
    this.setProperties({ resultCount: 0, urls: [] });

    return Discourse.Search.forTerm(term, {
      typeFilter: typeFilter,
      searchContext: this.get('searchContext')
    }).then(function(results) {
      var urls = [];
      if (results) {
        self.set('noResults', results.length === 0);

        var index = 0;
        results = _(['topic', 'category', 'user'])
            .map(function(n){
              return _(results).where({type: n}).first();
            })
            .compact()
            .each(function(list){
              _.each(list.results, function(item){
                item.index = index++;
                urls.pushObject(item.url);
              });
            })
            .value();

        self.setProperties({ resultCount: index, content: results, urls: urls });
      }

      self.set('loading', false);
    }).catch(function() {
      self.set('loading', false);
    });
  }, 300),

  showCancelFilter: function() {
    if (this.get('loading')) return false;
    return this.present('typeFilter');
  }.property('typeFilter', 'loading'),

  termChanged: function() {
    this.cancelTypeFilter();
  }.observes('term'),

  actions: {
    moreOfType: function(type) {
      this.set('typeFilter', type);
    },

    cancelType: function() {
      this.cancelTypeFilter();
    }
  },

  cancelTypeFilter: function() {
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
    var href = this.get('urls')[this.get("selectedIndex")];
    if (href) {
      Discourse.URL.routeTo(href);
    }
  }
});
