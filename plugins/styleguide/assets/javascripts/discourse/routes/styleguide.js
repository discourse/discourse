import Route from "@ember/routing/route";
import loadFaker from "discourse/lib/load-faker";
import { allCategories } from "discourse/plugins/styleguide/discourse/lib/styleguide";

export default class Styleguide extends Route {
  async model() {
    await loadFaker(); // So that it can be used synchronously in styleguide components
    return allCategories();
  }

  setupController(controller, categories) {
    controller.set("categories", categories);
  }
}
