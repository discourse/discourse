import { action } from "@ember/object";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class GroupManageLogs extends DiscourseRoute {
  titleToken() {
    return i18n("groups.manage.logs.title");
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
