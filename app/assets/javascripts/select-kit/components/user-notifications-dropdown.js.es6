import DropdownSelectBox from "select-kit/components/dropdown-select-box";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";

export default DropdownSelectBox.extend({
  classNames: ["user-notifications", "user-notifications-dropdown"],
  nameProperty: "label",
  init() {
    this._super(...arguments);
    if (this.get("user.ignored")) {
      this.set("headerIcon", "eye-slash");
      this.set("value", "changeToIgnored");
    } else if (this.get("user.muted")) {
      this.set("headerIcon", "times-circle");
      this.set("value", "changeToMuted");
    } else {
      this.set("headerIcon", "user");
      this.set("value", "changeToNormal");
    }
  },
  computeContent() {
    const content = [];

    content.push({
      icon: "user",
      id: "changeToNormal",
      description: I18n.t("user.user_notifications.normal_option_title"),
      label: I18n.t("user.user_notifications.normal_option")
    });

    content.push({
      icon: "times-circle",
      id: "changeToMuted",
      description: I18n.t("user.user_notifications.mute_option_title"),
      label: I18n.t("user.user_notifications.mute_option")
    });

    if (this.get("user.can_ignore_user")) {
      content.push({
        icon: "eye-slash",
        id: "changeToIgnored",
        description: I18n.t("user.user_notifications.ignore_option_title"),
        label: I18n.t("user.user_notifications.ignore_option")
      });
    }

    return content;
  },

  changeToNormal() {
    this.updateNotificationLevel("normal")
      .then(() => {
        this.set("user.ignored", false);
        this.set("user.muted", false);
        this.set("headerIcon", "user");
      })
      .catch(popupAjaxError);
  },
  changeToMuted() {
    this.updateNotificationLevel("mute")
      .then(() => {
        this.set("user.ignored", false);
        this.set("user.muted", true);
        this.set("headerIcon", "times-circle");
      })
      .catch(popupAjaxError);
  },
  changeToIgnored() {
    const controller = showModal("ignore-duration", {
      model: this.user
    });
    controller.setProperties({
      onSuccess: () => {
        this.set("headerIcon", "eye-slash");
      },
      onClose: () => {
        if (this.get("user.muted")) {
          this.set("headerIcon", "times-circle");
          this._select("changeToMuted");
        } else if (!this.get("user.muted") && !this.get("user.ignored")) {
          this.set("headerIcon", "user");
          this._select("changeToNormal");
        }
      }
    });
  },

  _select(id) {
    this.select(
      this.collectionComputedContent.find(c => c.originalContent.id === id)
    );
  },

  actions: {
    onSelect(level) {
      this[level]();
    }
  }
});
