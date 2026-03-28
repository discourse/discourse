import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseChatIntegrationProvidersIndex extends DiscourseRoute {
  @service router;

  afterModel() {
    const providers = this.modelFor(
      "adminPlugins.show.discourse-chat-integration-providers"
    );
    if (providers.enabled_providers.length > 0) {
      this.router.transitionTo(
        "adminPlugins.show.discourse-chat-integration-providers.show",
        providers.enabled_providers[0].name
      );
    }
  }
}
