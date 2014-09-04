export default Em.Controller.extend(Discourse.Presence, {

  contextChanged: function(){
    if(this.get('searchContextEnabled')){
      this._dontSearch = true;
      this.set('searchContextEnabled', false);
      this._dontSearch = false;
    }
  }.observes("searchContext"),

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
      }
    }
  }.property('searchContext'),

  searchContextEnabledChanged: function(){
    if(this._dontSearch){ return; }
    this.newSearchNeeded();
  }.observes('searchContextEnabled'),

  // If we need to perform another search
  newSearchNeeded: function() {
    this.set('noResults', false);
    var term = (this.get('term') || '').trim();
    if (term.length >= Discourse.SiteSettings.min_search_term_length) {
      this.set('loading', true);
      this.searchTerm(term, this.get('typeFilter'));
    } else {
      this.setProperties({ content: null });
    }
    this.set('selectedIndex', 0);
  }.observes('term', 'typeFilter'),

  searchTerm: Discourse.debouncePromise(function(term, typeFilter) {
    var self = this;

    var context;
    if(this.get('searchContextEnabled')){
      context = this.get('searchContext');
    }

    return Discourse.Search.forTerm(term, {
      typeFilter: typeFilter,
      searchContext: context
    }).then(function(results) {
      self.setProperties({ noResults: !results, content: results });
      self.set('loading', false);
    }).catch(function() {
      self.set('loading', false);
    });
  }, 400),

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
  }
});
