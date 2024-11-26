import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class GroupMessages extends DiscourseRoute {
  @service router;

  titleToken() {
    return i18n("groups.messages");
  }

  model() {
    return this.modelFor("group");
  }

  afterModel(group) {
    if (
      !group.get("is_group_user") &&
      !(this.currentUser && this.currentUser.admin)
    ) {
      this.router.transitionTo("group.members", group);
    }
  }

  @action
  triggerRefresh() {
    this.refresh();
  }
}
