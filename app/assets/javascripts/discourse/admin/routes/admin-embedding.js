import Route from "@ember/routing/route";

export default class AdminEmbeddingRoute extends Route {
  model() {
    return this.store.find("embedding");
  }

  setupController(controller, model) {
    controller.set("embedding", model);
  }
}
