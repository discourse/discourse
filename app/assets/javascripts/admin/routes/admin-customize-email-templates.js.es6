import Route from "@ember/routing/route";
export default Route.extend({
  model() {
    return this.store.findAll("email-template");
  },

  setupController(controller, model) {
    controller.set("emailTemplates", model);
  }
});
