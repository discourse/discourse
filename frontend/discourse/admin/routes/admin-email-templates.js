import Route from "@ember/routing/route";

export default class AdminEmailTemplatesRoute extends Route {
  model() {
    return this.store.findAll("email-template");
  }
}
