import showModal from "discourse/lib/show-modal";
import { ajax } from "discourse/lib/ajax";

export default {
  name: "avatar-select",

  initialize(container) {
    this.selectableAvatarsEnabled = container.lookup(
      "site-settings:main"
    ).selectable_avatars_enabled;

    container
      .lookup("service:app-events")
      .on("show-avatar-select", this, "_showAvatarSelect");
  },

  _showAvatarSelect(user) {
    const avatarTemplate = user.avatar_template;
    let selected = "uploaded";

    if (avatarTemplate === user.system_avatar_template) {
      selected = "system";
    } else if (avatarTemplate === user.gravatar_avatar_template) {
      selected = "gravatar";
    }

    const modal = showModal("avatar-selector");
    modal.setProperties({ user, selected });

    if (this.selectableAvatarsEnabled) {
      ajax("/site/selectable-avatars.json").then(avatars =>
        modal.set("selectableAvatars", avatars)
      );
    }
  }
};
