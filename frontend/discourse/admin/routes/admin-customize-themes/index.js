import Route from "@ember/routing/route";
import { service } from "discourse/lib/service";

export default class AdminCustomizeThemesIndexRoute extends Route {
  @service router;

  beforeModel() {
    this.router.transitionTo("adminConfig.customize.themes");
  }
}
