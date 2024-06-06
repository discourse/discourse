import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class GroupManageIndex extends DiscourseRoute {
  @service router;

  beforeModel() {
    this.router.transitionTo("group.manage.profile");
  }
}
