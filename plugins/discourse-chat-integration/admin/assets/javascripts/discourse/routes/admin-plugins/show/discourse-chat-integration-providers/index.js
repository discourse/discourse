import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseChatIntegrationProvidersIndex extends DiscourseRoute {
  model() {
    return this.modelFor(
      "adminPlugins.show.discourse-chat-integration-providers"
    );
  }
}
