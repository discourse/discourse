import { action } from "@ember/object";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class GroupManageLogs extends DiscourseRoute {
  titleToken() {
    return I18n.t("groups.manage.logs.title");
  }

  model() {
    return this.modelFor("group").findLogs();
  }

  setupController(controller, model) {
    this.controllerFor("group-manage-logs").setProperties({ model });
  }

  @action
  willTransition() {
    this.controllerFor("group-manage-logs").reset();
  }
}
