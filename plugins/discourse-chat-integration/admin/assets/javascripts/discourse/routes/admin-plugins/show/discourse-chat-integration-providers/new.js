import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseChatIntegrationProvidersNew extends DiscourseRoute {
  model() {
    return this.modelFor(
      "adminPlugins.show.discourse-chat-integration-providers"
    );
  }
}
