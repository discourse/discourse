import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class GroupManageMembership extends DiscourseRoute {
  @service router;

  titleToken() {
    return i18n("groups.manage.membership.title");
  }

  afterModel(group) {
    if (group.get("automatic")) {
      this.router.replaceWith("group.manage.interaction", group);
    }
  }
}
