import NotificationButtonHeader from "select-box-kit/components/notifications-button/notifications-button-header";
import computed from "ember-addons/ember-computed-decorators";
import { iconHTML } from 'discourse-common/lib/icon-library';

export default NotificationButtonHeader.extend({
  classNames: "category-notifications-button-header",
  shouldDisplaySelectedName: false,

  @computed("_selectedDetails.icon", "_selectedDetails.key")
  icon() {
    return `${this._super()}${iconHTML("caret-down")}`.htmlSafe();
  }
});
