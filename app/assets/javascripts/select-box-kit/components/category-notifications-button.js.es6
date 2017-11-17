import NotificationOptionsComponent from "select-box-kit/components/notifications-button";
import { iconHTML } from 'discourse-common/lib/icon-library';

export default NotificationOptionsComponent.extend({
  classNames: "category-notifications-button",
  isHidden: Ember.computed.or("category.deleted", "site.isMobileDevice"),
  i18nPrefix: "category.notifications",
  showFullTitle: false,

  computeValue() {
    return this.get("category.notification_level");
  },

  mutateValue(value) {
    this.get("category").setNotification(value);
  },

  computeHeaderContent() {
    let content = this._super();
    content.icons = [
      `${this.get("iconForSelectedDetails")}${iconHTML("caret-down")}`.htmlSafe()
    ];
    return content;
  },
});
