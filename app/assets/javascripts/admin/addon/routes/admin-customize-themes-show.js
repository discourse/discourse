import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class AdminCustomizeThemesShowRoute extends Route {
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
}
