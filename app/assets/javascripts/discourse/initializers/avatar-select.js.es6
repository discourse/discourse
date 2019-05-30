import showModal from "discourse/lib/show-modal";
import { ajax } from "discourse/lib/ajax";

export default {
  name: "avatar-select",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    const appEvents = container.lookup("app-events:main");

    appEvents.on("show-avatar-select", user => {
      const avatarTemplate = user.avatar_template;
      let selected = "uploaded";

      if (avatarTemplate === user.system_avatar_template) {
        selected = "system";
      } else if (avatarTemplate === user.gravatar_avatar_template) {
        selected = "gravatar";
      }

      const modal = showModal("avatar-selector");
      modal.setProperties({ user, selected });

      if (siteSettings.selectable_avatars_enabled) {
        ajax("/site/selectable-avatars.json").then(avatars =>
          modal.set("selectableAvatars", avatars)
        );
      }
    });
  }
};
