import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminCustomizeThemesShowRoute extends DiscourseRoute {
  @service router;

  serialize(model) {
    return { theme_id: model.get("id") };
  }

  model(params) {
    const all = this.modelFor("adminCustomizeThemes");
    const model = all.findBy("id", parseInt(params.theme_id, 10));
    if (model) {
      return model;
    } else {
      this.router.replaceWith("adminCustomizeThemes.index");
    }
  }

  setupController(controller) {
    super.setupController(...arguments);

    const parentController = this.controllerFor("adminCustomizeThemes");
    controller.set("allThemes", parentController.get("model"));
  }

  titleToken() {
    const model = this.controller.model;
    return model.name;
  }
}
