import Route from "@ember/routing/route";
export default Route.extend({
  model() {
    return this.store.find("embedding");
  },

  setupController(controller, model) {
    controller.set("embedding", model);
  }
});
