// A helper function to create a category route with parameters
export default function(filter, params) {
  return Discourse.Route.extend({
    model: function(modelParams) {
      return Discourse.Category.findBySlug(modelParams.slug, modelParams.parentSlug);
    },

    afterModel: function(model, transaction) {
      if (!model) {
        this.replaceWith('/404');
        return;
      }

      this.controllerFor('search').set('searchContext', model.get('searchContext'));
      this._setupNavigation(model);
      return Em.RSVP.all([this._createSubcategoryList(model),
                          this._retrieveTopicList(model, transaction)]);
    },

    _setupNavigation: function(model) {
      var noSubcategories = params && !!params.no_subcategories,
          filterMode = "category/" + Discourse.Category.slugFor(model) + (noSubcategories ? "/none" : "") + "/l/" + filter;

      this.controllerFor('navigation/category').setProperties({
        category: model,
        filterMode: filterMode,
        noSubcategories: params && params.no_subcategories,
        canEditCategory: Discourse.User.currentProp('staff'),
        canChangeCategoryNotificationLevel: Discourse.User.current()
      });
    },

    _createSubcategoryList: function(model) {
      this._categoryList = null;
      if (Em.isNone(model.get('parentCategory')) && Discourse.SiteSettings.show_subcategory_list) {
        var self = this;
        return Discourse.CategoryList.listForParent(model).then(function(list) {
          self._categoryList = list;
        });
      }

      // If we're not loading a subcategory list just resolve
      return Em.RSVP.resolve();
    },

    _retrieveTopicList: function(model, transaction) {
      var queryParams = transaction.queryParams,
          listFilter = "category/" + Discourse.Category.slugFor(model) + "/l/" + filter,
          self = this;

      params = params || {};

      if (queryParams && queryParams.order) { params.order = queryParams.order; }
      if (queryParams && queryParams.ascending) { params.ascending = queryParams.ascending; }
      if (queryParams && queryParams.status) { params.status = queryParams.status; }

      return Discourse.TopicList.list(listFilter, params).then(function(list) {
        var tracking = Discourse.TopicTrackingState.current();
        if (tracking) {
          tracking.sync(list, listFilter);
          tracking.trackIncoming(listFilter);
        }

        // If all the categories are the same, we can hide them
        var hideCategory = !list.get('topics').find(function (t) { return t.get('category') !== model; });
        list.set('hideCategory', hideCategory);
        self.set('topics', list);
      });
    },

    setupController: function(controller, model) {
      var topics = this.get('topics'),
          period = filter.indexOf('/') > 0 ? filter.split('/')[1] : '',
          filterText = I18n.t('filters.' + filter.replace('/', '.') + '.title', {count: 0});

      Discourse.set('title', I18n.t('filters.with_category', { filter: filterText, category: model.get('name').capitalize() }));

      this.controllerFor('navigation/category').set('canCreateTopic', topics.get('can_create_topic'));
      this.controllerFor('discovery/topics').setProperties({
        model: topics,
        category: model,
        period: period,
        selected: [],
        noSubcategories: params && !!params.no_subcategories
      });

      this.set('topics', null);
    },

    renderTemplate: function() {
      this.render('navigation/category', { outlet: 'navigation-bar' });

      if (this._categoryList) {
        this.render('discovery/categories', { outlet: 'header-list-container', model: this._categoryList });
      }
      this.render('discovery/topics', { controller: 'discovery/topics', outlet: 'list-container' });
    },

    deactivate: function() {
      this._super();
      this.controllerFor('search').set('searchContext', null);
    },

    actions: {
      setNotification: function(notification_level){
        this.currentModel.setNotification(notification_level);
      }
    }
  });
}
