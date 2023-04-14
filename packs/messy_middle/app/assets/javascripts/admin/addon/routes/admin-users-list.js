import { action } from "@ember/object";
import AdminUser from "admin/models/admin-user";
import DiscourseRoute from "discourse/routes/discourse";
import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";

export default class AdminUsersListRoute extends DiscourseRoute {
  @action
  exportUsers() {
    exportEntity("user_list", {
      trust_level: this.controllerFor("admin-users-list-show").get("query"),
    }).then(outputExportResult);
  }

  @action
  sendInvites() {
    this.transitionTo("userInvited", this.currentUser);
  }

  @action
  deleteUser(user) {
    AdminUser.create(user).destroy({ deletePosts: true });
  }
}
