import DropdownSelectBox from "select-kit/components/dropdown-select-box";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import discourseComputed from "discourse-common/utils/decorators";

export default DropdownSelectBox.extend({
  classNames: ["user-notifications", "user-notifications-dropdown"],
  nameProperty: "label",

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
        icon: "far-eye-slash",
        id: "changeToIgnored",
        description: I18n.t("user.user_notifications.ignore_option_title"),
        label: I18n.t("user.user_notifications.ignore_option")
      });
    }

    return content;
  },

  @discourseComputed("value")
  headerIcon(value) {
    return this.computeContent().find(row => row.id === value).icon;
  },

  changeToNormal() {
    this.updateNotificationLevel("normal").catch(popupAjaxError);
  },
  changeToMuted() {
    this.updateNotificationLevel("mute").catch(popupAjaxError);
  },
  changeToIgnored() {
    showModal("ignore-duration", {
      model: this.user
    });
  },

  @discourseComputed("user.ignored", "user.muted")
  value() {
    if (this.get("user.ignored")) {
      return "changeToIgnored";
    } else if (this.get("user.muted")) {
      return "changeToMuted";
    } else {
      return "changeToNormal";
    }
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
