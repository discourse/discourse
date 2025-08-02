import { action } from "@ember/object";
import { service } from "@ember/service";
import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminUsersRoute extends DiscourseRoute {
  @service router;

  titleToken() {
    return i18n("admin.config.users.title");
  }

  @action
  exportUsers() {
    exportEntity("user_list", {
      trust_level: this.controllerFor("admin-users-list-show").get("query"),
    }).then(outputExportResult);
  }

  @action
  sendInvites() {
    this.router.transitionTo("userInvited", this.currentUser);
  }
}
