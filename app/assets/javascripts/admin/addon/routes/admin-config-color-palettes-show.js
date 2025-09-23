import Route from "@ember/routing/route";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import ColorScheme from "admin/models/color-scheme";

export default class AdminConfigColorPalettesShowRoute extends Route {
  @service router;

  async model(params) {
    try {
      return ColorScheme.create(
        await ajax(`/admin/config/colors/${params.palette_id}`)
      );
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e);
      this.router.replaceWith("adminConfig.colorPalettes");
    }
  }

  serialize(model) {
    return { palette_id: model.get("id") };
  }
}
