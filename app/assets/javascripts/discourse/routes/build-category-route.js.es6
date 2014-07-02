// A helper function to create a category route with parameters
export default function(filter, params) {
  return Discourse.Route.extend({
    model: function(params) {
      return Discourse.Category.findBySlug(params.slug, params.parentSlug);
    },

    afterModel: function(model, transaction) {
      if (!model) {
        this.replaceWith('/404');
        return;
      }

      var self = this,
          noSubcategories = params && !!params.no_subcategories,
          filterMode = "category/" + Discourse.Category.slugFor(model) + (noSubcategories ? "/none" : "") + "/l/" + filter,
          listFilter = "category/" + Discourse.Category.slugFor(model) + "/l/" + filter;

      this.controllerFor('search').set('searchContext', model.get('searchContext'));

      var opts = { category: model, filterMode: filterMode };
      opts.noSubcategories = params && params.no_subcategories;
      opts.canEditCategory = Discourse.User.currentProp('staff');

      opts.canChangeCategoryNotificationLevel = Discourse.User.current();
      this.controllerFor('navigation/category').setProperties(opts);

      var queryParams = transaction.queryParams;
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
