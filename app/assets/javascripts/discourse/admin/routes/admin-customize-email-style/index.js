import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class AdminCustomizeEmailStyleIndexRoute extends Route {
  @service router;

  beforeModel() {
    this.router.replaceWith("adminCustomizeEmailStyle.edit", "html");
  }
}
