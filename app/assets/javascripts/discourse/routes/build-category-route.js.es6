import { queryParams, filterQueryParams } from 'discourse/routes/build-topic-route';

// A helper function to create a category route with parameters
export default function(filter, params) {
  return Discourse.Route.extend({
    queryParams: queryParams,

    model: function(modelParams) {
      return Discourse.Category.findBySlug(modelParams.slug, modelParams.parentSlug);
    },

    afterModel: function(model, transition) {
      if (!model) {
        this.replaceWith('/404');
        return;
      }

      this._setupNavigation(model);
      return Em.RSVP.all([this._createSubcategoryList(model),
                          this._retrieveTopicList(model, transition)]);
    },

    _setupNavigation: function(model) {
      var noSubcategories = params && !!params.no_subcategories,
          filterMode = "c/" + Discourse.Category.slugFor(model) + (noSubcategories ? "/none" : "") + "/l/" + filter;

      this.controllerFor('navigation/category').setProperties({
        category: model,
        filterMode: filterMode,
        noSubcategories: params && params.no_subcategories,
        canEditCategory: model.get('can_edit')
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

    _retrieveTopicList: function(model, transition) {
      var listFilter = "c/" + Discourse.Category.slugFor(model) + "/l/" + filter,
          self = this;

      var findOpts = filterQueryParams(transition.queryParams, params),
          extras = { cached: this.isPoppedState(transition) };

      return Discourse.TopicList.list(listFilter, findOpts, extras).then(function(list) {
        Discourse.TopicList.hideUniformCategory(list, model);
        self.set('topics', list);
      });
    },

    titleToken: function() {
      var filterText = I18n.t('filters.' + filter.replace('/', '.') + '.title', {count: 0}),
          model = this.currentModel;

      return I18n.t('filters.with_category', { filter: filterText, category: model.get('name') });
    },

    setupController: function(controller, model) {
      var topics = this.get('topics'),
          periodId = topics.get('for_period') || (filter.indexOf('/') > 0 ? filter.split('/')[1] : '');

      this.controllerFor('navigation/category').set('canCreateTopic', topics.get('can_create_topic'));
      this.controllerFor('discovery/topics').setProperties({
        model: topics,
        category: model,
        period: periodId,
        selected: [],
        noSubcategories: params && !!params.no_subcategories,
        order: topics.get('params.order'),
        ascending: topics.get('params.ascending'),
        expandAllPinned: true
      });

      this.controllerFor('search').set('searchContext', model.get('searchContext'));
      this.set('topics', null);

      this.openTopicDraft(topics);
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
