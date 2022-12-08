import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model(params) {
    return this.store.findAll("web-hook-event", params.web_hook_id);
  },

  setupController(controller, model) {
    controller.set("model", model);
    controller.subscribe();
  },

  deactivate() {
    this.controllerFor("adminWebHooks.show").unsubscribe();
  },

  renderTemplate() {
    this.render("admin/templates/web-hooks-show", { into: "adminApi" });
  },
});
