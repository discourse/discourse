import DropdownSelectBox from "select-kit/components/dropdown-select-box";
import {popupAjaxError} from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";

export default DropdownSelectBox.extend({
  classNames: ["user-notifications", "user-notifications-dropdown"],
  nameProperty: "label",
  allowInitialValueMutation: false,

  computeHeaderContent() {
    let content = this._super(...arguments);
    if (this.get("user.ignored")) {
      this.set("headerIcon", "eye-slash");
      content.name = `${I18n.t("user.user_notifications.ignore_option")}`;
    } else if (this.get("user.muted")) {
      this.set("headerIcon", "times-circle");
      content.name = `${I18n.t("user.user_notifications.mute_option")}`;
    } else {
      this.set("headerIcon", "user");
      content.name = `${I18n.t("user.user_notifications.normal_option")}`;
    }
    return content;
  },

  computeContent() {
    const content = [];

    content.push({
      icon: "user",
      id: "change-to-normal",
      description: I18n.t("user.user_notifications_normal_option_title"),
      action: () => this.send("reset"),
      label: I18n.t("user.user_notifications.normal_option")
    });

    content.push({
      icon: "times-circle",
      id: "change-to-muted",
      description: I18n.t("user.user_notifications.mute_option_title"),
      action: () => this.send("mute"),
      label: I18n.t("user.user_notifications.mute_option")
    });

    if (this.get("user.can_ignore_user")) {
      content.push({
        icon: "eye-slash",
        id: "change-to-ignored",
        description: I18n.t("user.user_notifications.ignore_option_title"),
        action: () => this.send("ignore"),
        label: I18n.t("user.user_notifications.ignore_option")
      });
    }

    return content;
  },

  actions: {
    reset() {
      this.get("updateNotificationLevel")("normal")
        .then(() => {
          this.set("user.ignored", false);
          this.set("user.muted", false);
          this.computeHeaderContent();
        })
        .catch(popupAjaxError);
    },
    mute() {
      this.get("updateNotificationLevel")("mute")
        .then(() => {
          this.set("user.ignored", false);
          this.set("user.muted", true);
          this.computeHeaderContent();
        })
        .catch(popupAjaxError);
    },
    ignore() {
      const controller = showModal("ignore-duration", {
        model: this.get("user")
      });
      controller.setProperties({
        refreshHeaderContent: () => { this.computeHeaderContent(); }
      });
    }
  }
});
