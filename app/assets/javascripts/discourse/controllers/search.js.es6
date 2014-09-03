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
      if (results) {

        // Topics might not be included
        if (!results.topics) { results.topics = []; }

        var topicMap = {};
        results.topics = results.topics.map(function(topic){
          topic = Discourse.Topic.create(topic);
          topicMap[topic.id] = topic;
          return topic;
        });

        results.posts = results.posts.map(function(post){
          post = Discourse.Post.create(post);
          post.set('topic', topicMap[post.topic_id]);
          return post;
        });

        results.users = results.users.map(function(user){
          user = Discourse.User.create(user);
          return user;
        });

        results.categories = results.categories.map(function(category){
          category = Discourse.Category.create(category);
          return category;
        });

        var r = results.grouped_search_result;
        results.resultTypes = [];

        // TODO: consider refactoring front end to take a better structure
        [['topic','posts'],['user','users'],['category','categories']].forEach(function(pair){
          var type = pair[0], name = pair[1];
          if(results[name].length > 0) {
            results.resultTypes.push({
              results: results[name],
              displayType: (context && Em.get(context, 'type') === 'topic' && type === 'topic') ? 'post' : type,
              type: type,
              more: r['more_' + name]
            });
          }
        });

        results.displayType = self.get('searchContext') === 'topic' ? 'post' : results.type;

        var noResults = !!((results.topics.length === 0) && (results.posts.length === 0) && (results.categories.length === 0));
        self.setProperties({ noResults: noResults, content: noResults ? null : Em.Object.create(results) });
      }
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
