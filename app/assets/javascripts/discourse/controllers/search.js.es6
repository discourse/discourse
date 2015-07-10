import Presence from 'discourse/mixins/presence';
import searchForTerm from 'discourse/lib/search-for-term';

var _dontSearch = false;

export default Em.Controller.extend(Presence, {

  contextType: function(key, value){
    if(arguments.length > 1) {
      // a bit hacky, consider cleaning this up, need to work through all observers though
      var context = $.extend({}, this.get('searchContext'));
      context.type = value;
      this.set('searchContext', context);
    }
    return this.get('searchContext.type');
  }.property('searchContext'),

  contextChanged: function(){
    if (this.get('searchContextEnabled')) {
      _dontSearch = true;
      this.set('searchContextEnabled', false);
      _dontSearch = false;
    }
  }.observes('searchContext'),

  fullSearchUrlRelative: function(){

    if (this.get('searchContextEnabled') && this.get('searchContext.type') === 'topic') {
      return null;
    }

    var url = '/search?q=' + encodeURIComponent(this.get('term'));
    var searchContext = this.get('searchContext');

    if (this.get('searchContextEnabled') && searchContext) {
      url += encodeURIComponent(" " + searchContext.type + ":" + searchContext.id);
    }

    return url;

  }.property('searchContext','term','searchContextEnabled'),

  fullSearchUrl: function(){
    var url = this.get('fullSearchUrlRelative');
    if (url) {
      return Discourse.getURL(url);
    }
  }.property('fullSearchUrlRelative'),

  searchContextDescription: function(){
    var ctx = this.get('searchContext');
    if (ctx) {
      switch(Em.get(ctx, 'type')) {
        case 'topic':
          return I18n.t('search.context.topic');
        case 'user':
          return I18n.t('search.context.user', {username: Em.get(ctx, 'user.username')});
        case 'category':
          return I18n.t('search.context.category', {category: Em.get(ctx, 'category.name')});
        case 'private_messages':
          return I18n.t('search.context.private_messages');
      }
    }
  }.property('searchContext'),

  searchContextEnabledChanged: function(){
    if (_dontSearch) { return; }
    this.newSearchNeeded();
  }.observes('searchContextEnabled'),

  // If we need to perform another search
  newSearchNeeded: function() {
    this.set('noResults', false);
    var term = (this.get('term') || '').trim();
    if (term.length >= Discourse.SiteSettings.min_search_term_length) {
      this.set('loading', true);

      Ember.run.debounce(this, 'searchTerm', term, this.get('typeFilter'), 400);
    } else {
      this.setProperties({ content: null });
    }
    this.set('selectedIndex', 0);
  }.observes('term', 'typeFilter'),

  searchTerm: function(term, typeFilter) {
    var self = this;

    var context;
    if(this.get('searchContextEnabled')){
      context = this.get('searchContext');
    }

    searchForTerm(term, {
      typeFilter: typeFilter,
      searchContext: context,
      fullSearchUrl: this.get('fullSearchUrl')
    }).then(function(results) {
      self.setProperties({ noResults: !results, content: results });
      self.set('loading', false);
    }).catch(function() {
      self.set('loading', false);
    });
  },

  showCancelFilter: function() {
    if (this.get('loading')) return false;
    return this.present('typeFilter');
  }.property('typeFilter', 'loading'),

  termChanged: function() {
    this.cancelTypeFilter();
  }.observes('term'),

  actions: {
    fullSearch: function() {
      var url = this.get('fullSearchUrlRelative');
      if (url) {
        Discourse.URL.routeTo(url);
      }
    },
    moreOfType: function(type) {
      this.set('typeFilter', type);
    },

    cancelType: function() {
      this.cancelTypeFilter();
    }
  },

  cancelTypeFilter: function() {
    this.set('typeFilter', null);
  }
});
