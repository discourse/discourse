import { DefaultNotificationItem } from "discourse/widgets/default-notification-item";
import { createWidgetFrom } from "discourse/widgets/widget";
import getURL from "discourse-common/lib/get-url";
import { iconNode } from "discourse-common/lib/icon-library";
import I18n from "discourse-i18n";

createWidgetFrom(DefaultNotificationItem, "new-features-notification-item", {
  text() {
    return I18n.t("notifications.new_features");
  },

  url() {
    return getURL("/admin");
  },

  icon() {
    return iconNode("gift");
  },
});
