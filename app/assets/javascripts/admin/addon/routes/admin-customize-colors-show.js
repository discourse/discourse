import Route from "@ember/routing/route";
import { service } from "@ember/service";
import ColorScheme from "admin/models/color-scheme";

export default class AdminCustomizeColorsShowRoute extends Route {
  @service router;

  model(params) {
    return ColorScheme.findAll().then((all) => {
      const model = all.findBy("id", parseInt(params.scheme_id, 10));
      if (model) {
        return model;
      } else {
        this.router.replaceWith("adminCustomize.colors");
      }
    });
  }

  serialize(model) {
    return { scheme_id: model.get("id") };
  }

  setupController(controller) {
    super.setupController(...arguments);
    ColorScheme.findAll().then((all) => {
      controller.set("allColors", all);
    });
  }
}
