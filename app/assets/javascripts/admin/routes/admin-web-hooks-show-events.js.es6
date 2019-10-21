import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model(params) {
    return this.store.findAll(
      "web-hook-event",
      Ember.get(params, "web_hook_id")
    );
  },

  setupController(controller, model) {
    controller.set("model", model);
    controller.subscribe();
  },

  deactivate() {
    this.controllerFor("adminWebHooks.showEvents").unsubscribe();
  },

  renderTemplate() {
    this.render("admin/templates/web-hooks-show-events", { into: "adminApi" });
  }
});
