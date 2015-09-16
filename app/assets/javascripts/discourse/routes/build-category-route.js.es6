import { queryParams, filterQueryParams, findTopicList } from 'discourse/routes/build-topic-route';

// A helper function to create a category route with parameters
export default (filter, params) => {
  return Discourse.Route.extend({
    queryParams: queryParams,

    model(modelParams) {
      return Discourse.Category.findBySlug(modelParams.slug, modelParams.parentSlug);
    },

    afterModel(model, transition) {
      if (!model) {
        this.replaceWith('/404');
        return;
      }

      this._setupNavigation(model);
      return Em.RSVP.all([this._createSubcategoryList(model),
                          this._retrieveTopicList(model, transition)]);
    },

    _setupNavigation(model) {
      const noSubcategories = params && !!params.no_subcategories,
            filterMode = `c/${Discourse.Category.slugFor(model)}${noSubcategories ? "/none" : ""}/l/${filter}`;

      this.controllerFor('navigation/category').setProperties({
        category: model,
        filterMode: filterMode,
        noSubcategories: params && params.no_subcategories,
        canEditCategory: model.get('can_edit')
      });
    },

    _createSubcategoryList(model) {
      this._categoryList = null;
      if (Em.isNone(model.get('parentCategory')) && Discourse.SiteSettings.show_subcategory_list) {
        return Discourse.CategoryList.listForParent(this.store, model)
                                     .then(list => this._categoryList = list);
      }

      // If we're not loading a subcategory list just resolve
      return Em.RSVP.resolve();
    },

    _retrieveTopicList(model, transition) {
      const listFilter = `c/${Discourse.Category.slugFor(model)}/l/${filter}`,
            findOpts = filterQueryParams(transition.queryParams, params),
             extras = { cached: this.isPoppedState(transition) };

      return findTopicList(this.store, this.topicTrackingState, listFilter, findOpts, extras).then(list => {
        Discourse.TopicList.hideUniformCategory(list, model);
        this.set('topics', list);
      });
    },

    titleToken() {
      const filterText = I18n.t('filters.' + filter.replace('/', '.') + '.title', { count: 0 }),
            model = this.currentModel;

      return I18n.t('filters.with_category', { filter: filterText, category: model.get('name') });
    },

    setupController(controller, model) {
      const topics = this.get('topics'),
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

      this.searchService.set('searchContext', model.get('searchContext'));
      this.set('topics', null);

      this.openTopicDraft(topics);
    },

    renderTemplate() {
      this.render('navigation/category', { outlet: 'navigation-bar' });

      if (this._categoryList) {
        this.render('discovery/categories', { outlet: 'header-list-container', model: this._categoryList });
      }
      this.render('discovery/topics', { controller: 'discovery/topics', outlet: 'list-container' });
    },

    deactivate() {
      this._super();
      this.searchService.set('searchContext', null);
    },

    actions: {
      setNotification(notification_level) {
        this.currentModel.setNotification(notification_level);
      }
    }
  });
};
