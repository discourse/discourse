export function buildGroupPage(type) {
  return Discourse.Route.extend({
    type,

    model() {
      return this.modelFor("group").findPosts({ type });
    },

    setupController(controller, model) {
      this.controllerFor('group-posts').setProperties({ model, type });
      this.controllerFor("group").set("showing", type);
    },

    renderTemplate() {
      this.render('group-posts');
    },

    actions: {
      didTransition() { return true; }
    }
  });
}

export default buildGroupPage('posts');
