import Route from "@ember/routing/route";
import { inject as service } from "@ember/service";

export default class AdminCustomizeColorsShowRoute extends Route {
  @service router;

  model(params) {
    const all = this.modelFor("adminCustomize.colors");
    const model = all.findBy("id", parseInt(params.scheme_id, 10));
    if (model) {
      return model;
    } else {
      this.router.replaceWith("adminCustomize.colors.index");
    }
  }

  serialize(model) {
    return { scheme_id: model.get("id") };
  }

  setupController(controller, model) {
    controller.set("model", model);
    controller.set("allColors", this.modelFor("adminCustomize.colors"));
  }
}
