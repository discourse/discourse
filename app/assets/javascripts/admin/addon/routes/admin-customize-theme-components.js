import Route from "@ember/routing/route";
import { service } from "@ember/service";
import { COMPONENTS } from "admin/models/theme";

export default class AdminCustomizeThemeComponents extends Route {
  @service router;

  beforeModel(transition) {
    transition.abort();
    this.router.transitionTo("adminCustomizeThemes", {
      queryParams: { tab: COMPONENTS },
    });
  }
}
