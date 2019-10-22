import DiscourseRoute from "discourse/routes/discourse";
import AdminUser from "admin/models/admin-user";

export default DiscourseRoute.extend({
  serialize(model) {
    return {
      user_id: model.get("id"),
      username: model.get("username").toLowerCase()
    };
  },

  model(params) {
    return AdminUser.find(Ember.get(params, "user_id"));
  },

  renderTemplate() {
    this.render({ into: "admin" });
  },

  afterModel(adminUser) {
    return adminUser.loadDetails().then(function() {
      adminUser.setOriginalTrustLevel();
      return adminUser;
    });
  }
});
