export function buildIndex(type) {
  return Discourse.Route.extend({
    type,

    model() {
      return this.modelFor("group").findPosts({ type });
    },

    setupController(controller, model) {
      this.controllerFor('group-index').setProperties({ model, type });
      this.controllerFor("group").set("showing", type);
    },

    renderTemplate() {
      this.render('group-index');
    },

    actions: {
      didTransition() { return true; }
    }
  });
}

export default buildIndex('posts');
