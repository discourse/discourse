import ShowFooter from "discourse/mixins/show-footer";

Discourse.DiscoveryCategoriesRoute = Discourse.Route.extend(Discourse.OpenComposer, ShowFooter, {
  renderTemplate: function() {
    this.render('navigation/categories', { outlet: 'navigation-bar' });
    this.render('discovery/categories', { outlet: 'list-container' });
  },

  beforeModel: function() {
    this.controllerFor('navigation/categories').set('filterMode', 'categories');
  },

  model: function() {
    // TODO: Remove this and ensure server side does not supply `topic_list`
    // if default page is categories
    PreloadStore.remove("topic_list");

    return Discourse.CategoryList.list('categories').then(function(list) {
      var tracking = Discourse.TopicTrackingState.current();
      if (tracking) {
        tracking.sync(list, 'categories');
        tracking.trackIncoming('categories');
      }
      return list;
    });
  },

  titleToken: function() {
    return I18n.t('filters.categories.title');
  },

  setupController: function(controller, model) {
    controller.set('model', model);

    // Only show either the Create Category or Create Topic button
    this.controllerFor('navigation/categories').set('canCreateCategory', model.get('can_create_category'));
    this.controllerFor('navigation/categories').set('canCreateTopic', model.get('can_create_topic') && !model.get('can_create_category'));

    this.openTopicDraft(model);
  },

  actions: {
    createCategory: function() {
      var groups = Discourse.Site.current().groups;
      var everyone_group = groups.findBy('id', 0);
      var group_names = groups.map(function(group) {
        return group.name;
      });

      Discourse.Route.showModal(this, 'editCategory', Discourse.Category.create({
        color: 'AB9364', text_color: 'FFFFFF', group_permissions: [{group_name: everyone_group.name, permission_type: 1}],
        available_groups: group_names,
        allow_badges: true
      }));
      this.controllerFor('editCategory').set('selectedTab', 'general');
    },

    createTopic: function() {
      this.openComposer(this.controllerFor('discovery/categories'));
    }
  }
});

export default Discourse.DiscoveryCategoriesRoute;
