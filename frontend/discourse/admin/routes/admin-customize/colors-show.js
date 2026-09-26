import Route from "@ember/routing/route";
import { service } from "discourse/lib/service";

export default class AdminCustomizeColorsShowRoute extends Route {
  @service router;

  beforeModel(transition) {
    transition.abort();
    this.router.replaceWith(
      "adminConfig.colorPalettes.show",
      transition.to.params.scheme_id
    );
  }
}
