import { get } from "@ember/object";
import DiscourseRoute from "discourse/routes/discourse";
import AdminUser from "admin/models/admin-user";

export default class AdminUserRoute extends DiscourseRoute {
  serialize(model) {
    return {
      user_id: model.get("id"),
      username: model.get("username").toLowerCase(),
    };
  }

  model(params) {
    return AdminUser.find(get(params, "user_id"));
  }

  afterModel(adminUser) {
    return adminUser.loadDetails().then(function () {
      adminUser.setOriginalTrustLevel();
      return adminUser;
    });
  }
}
