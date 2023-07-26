import DropdownSelectBox from "select-kit/components/dropdown-select-box";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import { computed } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import IgnoreDurationModal from "discourse/components/modal/ignore-duration-with-username";

export default DropdownSelectBox.extend({
  modal: service(),

  classNames: ["user-notifications", "user-notifications-dropdown"],

  selectKitOptions: {
    headerIcon: "userNotificationIcon",
    showCaret: true,
  },

  userNotificationIcon: computed("mainCollection.[]", "value", function () {
    return (
      this.mainCollection &&
      this.mainCollection.find((row) => row.id === this.value).icon
    );
  }),

  content: computed(function () {
    const content = [];

    content.push({
      icon: "user",
      id: "changeToNormal",
      description: I18n.t("user.user_notifications.normal_option_title"),
      name: I18n.t("user.user_notifications.normal_option"),
    });

    content.push({
      icon: "times-circle",
      id: "changeToMuted",
      description: I18n.t("user.user_notifications.mute_option_title"),
      name: I18n.t("user.user_notifications.mute_option"),
    });

    if (this.get("user.can_ignore_user")) {
      content.push({
        icon: "far-eye-slash",
        id: "changeToIgnored",
        description: I18n.t("user.user_notifications.ignore_option_title"),
        name: I18n.t("user.user_notifications.ignore_option"),
      });
    }

    return content;
  }),

  changeToNormal() {
    this.updateNotificationLevel({ level: "normal" }).catch(popupAjaxError);
  },
  changeToMuted() {
    this.updateNotificationLevel({ level: "mute" }).catch(popupAjaxError);
  },
  changeToIgnored() {
    this.modal.show(IgnoreDurationModal, {
      model: {
        ignoredUsername: this.user.username,
        enableSelection: false,
      },
    });
  },

  actions: {
    onChange(level) {
      this[level]();

      // hack but model.ignored/muted is not
      // getting updated after updateNotificationLevel
      this.set("value", level);
    },
  },
});
