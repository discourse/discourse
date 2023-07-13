import Route from "@ember/routing/route";
import { allCategories } from "discourse/plugins/styleguide/discourse/lib/styleguide";

export default class Styleguide extends Route {
  model() {
    return allCategories();
  }

  setupController(controller, categories) {
    controller.set("categories", categories);
  }
}
