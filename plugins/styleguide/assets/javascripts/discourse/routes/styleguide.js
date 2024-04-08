import Route from "@ember/routing/route";
import { loadFabricators } from "discourse/lib/load-fabricators";
import { allCategories } from "discourse/plugins/styleguide/discourse/lib/styleguide";

export default class Styleguide extends Route {
  async model() {
    await loadFabricators(); // So that it can be used synchronously in styleguide components
    return allCategories();
  }

  setupController(controller, categories) {
    controller.set("categories", categories);
  }
}
