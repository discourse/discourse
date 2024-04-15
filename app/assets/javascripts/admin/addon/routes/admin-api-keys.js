import { action } from "@ember/object";
import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class AdminApiKeysRoute extends Route {
  @service router;

  @action
  show(apiKey) {
    this.router.transitionTo("adminApiKeys.show", apiKey.id);
  }

  @action
  new() {
    this.router.transitionTo("adminApiKeys.new");
  }
}
