import Route from "@ember/routing/route";
import { service } from "discourse/lib/service";

export default class AdminApiIndexRoute extends Route {
  @service router;

  beforeModel() {
    this.router.transitionTo("adminApiKeys");
  }
}
