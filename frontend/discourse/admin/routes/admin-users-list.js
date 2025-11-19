import { action } from "@ember/object";
import AdminUser from "discourse/admin/models/admin-user";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminUsersListRoute extends DiscourseRoute {
  @action
  deleteUser(user) {
    AdminUser.create(user).destroy({ deletePosts: true });
  }
}
