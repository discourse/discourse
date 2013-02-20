(function() {

  Discourse.ListController = Ember.Controller.extend(Discourse.Presence, {
    currentUserBinding: 'Discourse.currentUser',
    categoriesBinding: 'Discourse.site.categories',
    categoryBinding: 'topicList.category',
    canCreateCategory: false,
    canCreateTopic: false,
    needs: ['composer', 'modal', 'listTopics'],
    availableNavItems: (function() {
      var hasCategories, loggedOn, summary;
      summary = this.get('filterSummary');
      loggedOn = !!Discourse.get('currentUser');
      hasCategories = !!this.get('categories');
      return Discourse.SiteSettings.top_menu.split("|").map(function(i) {
        return Discourse.NavItem.fromText(i, {
          loggedOn: loggedOn,
          hasCategories: hasCategories,
          countSummary: summary
        });
      }).filter(function(i) {
        return i !== null;
      });
    }).property('filterSummary'),
    load: function(filterMode) {
      var current,
        _this = this;
      this.set('loading', true);
      if (filterMode === 'categories') {
        return Ember.Deferred.promise(function(deferred) {
          return Discourse.CategoryList.list(filterMode).then(function(items) {
            _this.set('loading', false);
            _this.set('filterMode', filterMode);
            _this.set('categoryMode', true);
            return deferred.resolve(items);
          });
        });
      } else {
        current = (this.get('availableNavItems').filter(function(f) {
          return f.name === filterMode;
        }))[0];
        if (!current) {
          current = Discourse.NavItem.create({
            name: filterMode
          });
        }
        return Ember.Deferred.promise(function(deferred) {
          return Discourse.TopicList.list(current).then(function(items) {
            _this.set('filterSummary', items.filter_summary);
            _this.set('filterMode', filterMode);
            _this.set('loading', false);
            return deferred.resolve(items);
          });
        });
      }
    },
    /* Put in the appropriate page title based on our view
    */

    updateTitle: (function() {
      if (this.get('filterMode') === 'categories') {
        return Discourse.set('title', Em.String.i18n('categories_list'));
      } else {
        if (this.present('category')) {
          return Discourse.set('title', "" + (this.get('category.name').capitalize()) + " " + (Em.String.i18n('topic.list')));
        } else {
          return Discourse.set('title', Em.String.i18n('topic.list'));
        }
      }
    }).observes('filterMode', 'category'),
    /* Create topic button
    */

    createTopic: function() {
      var topicList;
      topicList = this.get('controllers.listTopics.content');
      if (!topicList) {
        return;
      }
      return this.get('controllers.composer').open({
        categoryName: this.get('category.name'),
        action: Discourse.Composer.CREATE_TOPIC,
        draftKey: topicList.get('draft_key'),
        draftSequence: topicList.get('draft_sequence')
      });
    },
    createCategory: function() {
      var _ref;
      return (_ref = this.get('controllers.modal')) ? _ref.show(Discourse.EditCategoryView.create()) : void 0;
    }
  });

  Discourse.ListController.reopenClass({
    filters: ['popular', 'favorited', 'read', 'unread', 'new', 'posted']
  });

}).call(this);
