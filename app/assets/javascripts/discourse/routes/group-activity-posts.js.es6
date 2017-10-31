export function buildGroupPage(type) {
  return Discourse.Route.extend({
    type,

    titleToken() {
      return I18n.t(`groups.${type}`);
    },

    model(params, transition) {
      let categoryId = Ember.get(transition, 'queryParams.category_id');
      return this.modelFor("group").findPosts({ type, categoryId });
    },

    setupController(controller, model) {
      this.controllerFor('group-activity-posts').setProperties({ model, type });
      this.controllerFor("group").set("showing", type);
    },

    renderTemplate() {
      this.render('group-activity-posts');
    },

    actions: {
      didTransition() { return true; }
    }
  });
}

export default buildGroupPage('posts');
