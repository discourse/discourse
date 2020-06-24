import DiscourseRoute from "discourse/routes/discourse";
import { exportEntity } from "discourse/lib/export-csv";
import { outputExportResult } from "discourse/lib/export-result";
import AdminUser from "admin/models/admin-user";

export default DiscourseRoute.extend({
  actions: {
    exportUsers() {
      exportEntity("user_list", {
        trust_level: this.controllerFor("admin-users-list-show").get("query")
      }).then(outputExportResult);
    },

    sendInvites() {
      this.transitionTo("userInvited", this.currentUser);
    },

    deleteUser(user) {
      AdminUser.create(user).destroy({ deletePosts: true });
    }
  }
});
