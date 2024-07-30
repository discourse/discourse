import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class GroupMembers extends DiscourseRoute {
  @service router;

  beforeModel() {
    this.router.transitionTo("group.index");
  }
}
