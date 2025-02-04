import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class GroupManage extends DiscourseRoute {
  @service router;

  titleToken() {
    return i18n("groups.manage.title");
  }

  model() {
    return this.modelFor("group");
  }

  afterModel(group) {
    if (
      !this.currentUser ||
      (!(this.modelFor("group").can_admin_group && group.get("automatic")) &&
        !this.currentUser.canManageGroup(group))
    ) {
      this.router.transitionTo("group.members", group);
    }
  }

  setupController(controller, model) {
    this.controllerFor("group-manage").setProperties({ model });
    this.controllerFor("group").set("showing", "manage");
  }
}
