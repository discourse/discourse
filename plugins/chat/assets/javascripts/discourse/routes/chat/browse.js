import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class extends Route {
  @service router;
  @service currentUser;

  beforeModel() {
    if (!this.currentUser) {
      return this.router.replaceWith("chat.channels");
    }
  }
}
