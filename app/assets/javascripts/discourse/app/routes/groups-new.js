import { service } from "@ember/service";
import Group from "discourse/models/group";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class GroupsNew extends DiscourseRoute {
  @service router;

  titleToken() {
    return I18n.t("admin.groups.new.title");
  }

  model() {
    return Group.create({
      automatic: false,
      visibility_level: 0,
      can_admin_group: true,
    });
  }

  afterModel() {
    if (!this.get("currentUser.can_create_group")) {
      this.router.transitionTo("groups");
    }
  }
}
