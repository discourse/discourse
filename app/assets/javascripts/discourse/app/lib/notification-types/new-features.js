import NotificationTypeBase from "discourse/lib/notification-types/base";
import getURL from "discourse-common/lib/get-url";
import I18n from "I18n";

export default class extends NotificationTypeBase {
  get label() {
    return null;
  }

  get description() {
    return I18n.t("notifications.new_features");
  }

  get linkHref() {
    return getURL("/admin");
  }

  get icon() {
    return "gift";
  }
}
