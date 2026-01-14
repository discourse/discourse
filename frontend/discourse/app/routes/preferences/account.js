import { action } from "@ember/object";
import { service } from "@ember/service";
import AvatarSelectorModal from "discourse/components/modal/avatar-selector";
import UserBadge from "discourse/models/user-badge";
import RestrictedUserRoute from "discourse/routes/restricted-user";
import { i18n } from "discourse-i18n";

export default class PreferencesAccount extends RestrictedUserRoute {
  @service modal;

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
  }

  setupController(controller, user) {
    controller.reset();
    controller.setProperties({
      model: user,
      newNameInput: user.get("name"),
      newTitleInput: user.get("title"),
      newPrimaryGroupInput: user.get("primary_group_id"),
      newFlairGroupId: user.get("flair_group_id"),
      newStatus: user.status,
      subpageTitle: i18n("user.preferences_nav.account"),
    });
  }

  @action
  showAvatarSelector(user) {
    this.modal.show(AvatarSelectorModal, {
      model: { user },
    });
  }
}
