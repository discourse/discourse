import Route from "@ember/routing/route";
import { service } from "discourse/lib/service";

export default class GroupMessagesIndex extends Route {
  @service router;

  beforeModel() {
    this.router.transitionTo("group.messages.inbox");
  }
}
