import NotificationOptionsComponent from "select-box-kit/components/notifications-button";
import { iconHTML } from "discourse-common/lib/icon-library";

export default NotificationOptionsComponent.extend({
  classNames: "tag-notifications-button",
  i18nPrefix: "tagging.notifications",
  headerIcon: `${this._super()}${iconHTML("caret-down")}`.htmlSafe(),
  computedHeaderText: null,

  actions: {
    onSelect(value) {
      this.defaultOnSelect();
      this.sendAction("action", value);
    }
  }
});
