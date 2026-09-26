import Controller from "@ember/controller";
import { service } from "discourse/lib/service";

export default class GroupMessagesController extends Controller {
  @service router;

  get isGroup() {
    return this.router.currentRoute.parent.name === "group.messages";
  }
}
