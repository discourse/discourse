import { action } from "@ember/object";
import DiscourseRoute from "discourse/routes/discourse";
import AdminUser from "admin/models/admin-user";

export default class AdminUsersListRoute extends DiscourseRoute {
  @action
  deleteUser(user) {
    AdminUser.create(user).destroy({ deletePosts: true });
  }
}
