import Composer from 'discourse/models/composer';
import showModal from "discourse/lib/show-modal";
import { findTopicList } from 'discourse/routes/build-topic-route';

export default Discourse.Route.extend({
  navMode: 'latest',

  renderTemplate() {
    const controller = this.controllerFor('tags.show');
    this.render('tags.show', { controller });
  },

  model(params) {
    var tag = this.store.createRecord("tag", { id: Handlebars.Utils.escapeExpression(params.tag_id) }),
        f = '';

    if (params.category) {
      f = 'c/';
      if (params.parent_category) { f += params.parent_category + '/'; }
      f += params.category + '/l/';
    }
    f += this.get('navMode');
    this.set('filterMode', f);

    if (params.category) { this.set('categorySlug', params.category); }
    if (params.parent_category) { this.set('parentCategorySlug', params.parent_category); }

    if (this.get("currentUser")) {
      // If logged in, we should get the tag"s user settings
      return this.store.find("tagNotification", tag.get("id")).then(tn => {
        this.set("tagNotification", tn);
        return tag;
      });
    }

    return tag;
  },

  afterModel(tag) {
    const controller = this.controllerFor('tags.show');
    controller.set('loading', true);

    const params = controller.getProperties('order', 'ascending');

    const categorySlug = this.get('categorySlug');
    const parentCategorySlug = this.get('parentCategorySlug');
    const filter = this.get('navMode');

    if (categorySlug) {
      var category = Discourse.Category.findBySlug(categorySlug, parentCategorySlug);
      if (parentCategorySlug) {
        params.filter = `tags/c/${parentCategorySlug}/${categorySlug}/${tag.id}/l/${filter}`;
      } else {
        params.filter = `tags/c/${categorySlug}/${tag.id}/l/${filter}`;
      }

      this.set('category', category);
    } else {
      params.filter = `tags/${tag.id}/l/${filter}`;
      this.set('category', null);
    }

    return findTopicList(this.store, this.topicTrackingState, params.filter, params, {}).then(function(list) {
      controller.set('list', list);
      controller.set('canCreateTopic', list.get('can_create_topic'));
      if (list.topic_list.tags) {
        Discourse.Site.currentProp('top_tags', list.topic_list.tags);
      }
      controller.set('loading', false);
    });
  },

  titleToken() {
    const filterText = I18n.t('filters.' + this.get('navMode').replace('/', '.') + '.title'),
          controller = this.controllerFor('tags.show');

    if (this.get('category')) {
      return I18n.t('tagging.filters.with_category', { filter: filterText, tag: controller.get('model.id'), category: this.get('category.name')});
    } else {
      return I18n.t('tagging.filters.without_category', { filter: filterText, tag: controller.get('model.id')});
    }
  },

  setupController(controller, model) {
    this.controllerFor('tags.show').setProperties({
      model,
      tag: model,
      category: this.get('category'),
      filterMode: this.get('filterMode'),
      navMode: this.get('navMode'),
      tagNotification: this.get('tagNotification')
    });
  },

  actions: {
    invalidateModel() {
      this.refresh();
    },

    renameTag(tag) {
      showModal("rename-tag", { model: tag });
    },

    createTopic() {
      var controller = this.controllerFor("tags.show"),
          self = this;

      this.controllerFor('composer').open({
        categoryId: controller.get('category.id'),
        action: Composer.CREATE_TOPIC,
        draftKey: controller.get('list.draft_key'),
        draftSequence: controller.get('list.draft_sequence')
      }).then(function() {
        // Pre-fill the tags input field
        if (controller.get('model.id')) {
          var c = self.controllerFor('composer').get('model');
          c.set('tags', [controller.get('model.id')]);
        }
      });
    },

    didTransition() {
      this.controllerFor("tags.show")._showFooter();
      return true;
    },

    willTransition(transition) {
      if (!Discourse.SiteSettings.show_filter_by_tag) { return true; }

      if ((transition.targetName.indexOf("discovery.parentCategory") !== -1 ||
            transition.targetName.indexOf("discovery.category") !== -1) && !transition.queryParams.allTags ) {
        this.transitionTo("/tags" + transition.intent.url + "/" + this.currentModel.get("id"));
      }
      return true;
    }
  }
});
