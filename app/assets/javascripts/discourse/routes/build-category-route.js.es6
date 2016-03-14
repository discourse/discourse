import { filterQueryParams, findTopicList } from 'discourse/routes/build-topic-route';
import { queryParams } from 'discourse/controllers/discovery-sortable';
import TopicList from 'discourse/models/topic-list';
import PermissionType from 'discourse/models/permission-type';
import CategoryList from 'discourse/models/category-list';
import Category from 'discourse/models/category';

// A helper function to create a category route with parameters
export default (filter, params) => {
  return Discourse.Route.extend({
    queryParams,

    model(modelParams) {
      const category = Category.findBySlug(modelParams.slug, modelParams.parentSlug);
      if (!category) {
        return Category.reloadBySlug(modelParams.slug, modelParams.parentSlug).then((atts) => {
          if (modelParams.parentSlug) {
            atts.category.parentCategory = Category.findBySlug(modelParams.parentSlug);
          }
          const record = this.store.createRecord('category', atts.category);
          record.setupGroupsAndPermissions();
          this.site.updateCategory(record);
          return { category: Category.findBySlug(modelParams.slug, modelParams.parentSlug) };
        });
      };
      return { category };
    },

    afterModel(model, transition) {
      if (!model) {
        this.replaceWith('/404');
        return;
      }

      this._setupNavigation(model.category);
      return Em.RSVP.all([this._createSubcategoryList(model.category),
                          this._retrieveTopicList(model.category, transition)]);
    },

    _setupNavigation(category) {
      const noSubcategories = params && !!params.no_subcategories,
            filterMode = `c/${Discourse.Category.slugFor(category)}${noSubcategories ? "/none" : ""}/l/${filter}`;

      this.controllerFor('navigation/category').setProperties({
        category,
        filterMode: filterMode,
        noSubcategories: params && params.no_subcategories,
        canEditCategory: category.get('can_edit')
      });
    },

    _createSubcategoryList(category) {
      this._categoryList = null;
      if (Em.isNone(category.get('parentCategory')) && Discourse.SiteSettings.show_subcategory_list) {
        return CategoryList.listForParent(this.store, category).then(list => this._categoryList = list);
      }

      // If we're not loading a subcategory list just resolve
      return Em.RSVP.resolve();
    },

    _retrieveTopicList(category, transition) {
      const listFilter = `c/${Discourse.Category.slugFor(category)}/l/${filter}`,
            findOpts = filterQueryParams(transition.queryParams, params),
             extras = { cached: this.isPoppedState(transition) };

      return findTopicList(this.store, this.topicTrackingState, listFilter, findOpts, extras).then(list => {
        TopicList.hideUniformCategory(list, category);
        this.set('topics', list);
        return list;
      });
    },

    titleToken() {
      const filterText = I18n.t('filters.' + filter.replace('/', '.') + '.title'),
            category = this.currentModel.category;

      return I18n.t('filters.with_category', { filter: filterText, category: category.get('name') });
    },

    setupController(controller, model) {
      const topics = this.get('topics'),
            category = model.category,
            canCreateTopic = topics.get('can_create_topic'),
            canCreateTopicOnCategory = category.get('permission') === PermissionType.FULL;

      this.controllerFor('navigation/category').setProperties({
        canCreateTopicOnCategory: canCreateTopicOnCategory,
        cannotCreateTopicOnCategory: !canCreateTopicOnCategory,
        canCreateTopic: canCreateTopic
      });

      var topicOpts = {
        model: topics,
        category,
        period: topics.get('for_period') || (filter.indexOf('/') > 0 ? filter.split('/')[1] : ''),
        selected: [],
        noSubcategories: params && !!params.no_subcategories,
        expandAllPinned: true,
        canCreateTopic: canCreateTopic,
        canCreateTopicOnCategory: canCreateTopicOnCategory
      };

      const p = category.get('params');
      if (p && Object.keys(p).length) {
        if (p.order !== undefined) {
          topicOpts.order = p.order;
        }
        if (p.ascending !== undefined) {
          topicOpts.ascending = p.ascending;
        }
      }

      this.controllerFor('discovery/topics').setProperties(topicOpts);
      this.searchService.set('searchContext', category.get('searchContext'));
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

    resetController(controller, isExiting) {
      if (isExiting) {
        controller.setProperties({ order: "default", ascending: false });
      }
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
