import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseChatIntegrationProviders extends DiscourseRoute {
  model() {
    return this.store.findAll("provider");
  }
}
