import { action } from "@ember/object";
import { service } from "@ember/service";
import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";
import DiscourseRoute from "discourse/routes/discourse";
import AdminUser from "admin/models/admin-user";

export default class AdminUsersListRoute extends DiscourseRoute {
  @service router;

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

  @action
  deleteUser(user) {
    AdminUser.create(user).destroy({ deletePosts: true });
  }
}
