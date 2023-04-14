import { action } from "@ember/object";
import Route from "@ember/routing/route";

export default class AdminApiKeysRoute extends Route {
  @action
  show(apiKey) {
    this.transitionTo("adminApiKeys.show", apiKey.id);
  }

  @action
  new() {
    this.transitionTo("adminApiKeys.new");
  }
}
