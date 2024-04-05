import Route from "@ember/routing/route";
import { service } from "@ember/service";
import { allCategories } from "discourse/plugins/styleguide/discourse/lib/styleguide";

export default class Styleguide extends Route {
  @service styleguide;

  async model() {
    await this.styleguide.ensureFakerLoaded(); // So that it can be used synchronously in styleguide components
    return allCategories();
  }

  setupController(controller, categories) {
    controller.set("categories", categories);
  }
}
