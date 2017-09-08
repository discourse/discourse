import NotificationOptionsComponent from "discourse/components/notification-options";
import { observes } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import { iconHTML } from "discourse-common/lib/icon-library";

export default NotificationOptionsComponent.extend({
  classNames: ["tag-notification-options"],

  i18nPrefix: "tagging.notifications",

  @observes("value")
  _notificationLevelChanged() {
    this.sendAction("action", this.get("value"));
  },

  @computed("value")
  icon() {
    return `${this._super()}${iconHTML("caret-down")}`.htmlSafe();
  },

  generatedHeadertext: null
});
