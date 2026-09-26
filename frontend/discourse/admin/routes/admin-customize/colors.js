import Route from "@ember/routing/route";
import { service } from "discourse/lib/service";

export default class AdminCustomizeColorsRoute extends Route {
  @service router;

  beforeModel(transition) {
    transition.abort();
    this.router.replaceWith("adminConfig.colorPalettes");
  }
}
