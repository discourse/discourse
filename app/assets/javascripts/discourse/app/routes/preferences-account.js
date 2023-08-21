import RestrictedUserRoute from "discourse/routes/restricted-user";
import UserBadge from "discourse/models/user-badge";
import showModal from "discourse/lib/show-modal";
import { action } from "@ember/object";
import I18n from "I18n";

export default RestrictedUserRoute.extend({
  model() {
    const user = this.modelFor("user");
    if (this.siteSettings.enable_badges) {
      return UserBadge.findByUsername(user.get("username")).then(
        (userBadges) => {
          user.set(
            "badges",
            userBadges.map((ub) => ub.badge)
          );
          return user;
        }
      );
    } else {
      return user;
    }
  },

  setupController(controller, user) {
    controller.reset();
    controller.setProperties({
      model: user,
      newNameInput: user.get("name"),
      newTitleInput: user.get("title"),
      newPrimaryGroupInput: user.get("primary_group_id"),
      newFlairGroupId: user.get("flair_group_id"),
      newStatus: user.status,
      subpageTitle: I18n.t("user.preferences_nav.account"),
    });
  },

  @action
  showAvatarSelector(user) {
    showModal("avatar-selector").setProperties({ user });
  },
});
