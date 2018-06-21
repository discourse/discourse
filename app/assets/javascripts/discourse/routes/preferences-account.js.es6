import UserBadge from "discourse/models/user-badge";
import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  showFooter: true,

  model: function() {
    const user = this.modelFor("user");
    if (this.siteSettings.enable_badges) {
      return UserBadge.findByUsername(
        this.modelFor("user").get("username")
      ).then(userBadges => {
        user.set("badges", userBadges.map(ub => ub.badge));
        return user;
      });
    } else {
      return user;
    }
  },

  setupController(controller, user) {
    controller.reset();
    controller.setProperties({
      model: user,
      newNameInput: user.get("name"),
      newTitleInput: user.get("title")
    });
  }
});
