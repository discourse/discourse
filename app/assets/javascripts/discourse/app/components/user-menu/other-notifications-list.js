import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";
import { inject as service } from "@ember/service";

export default class UserMenuOtherNotificationsList extends UserMenuNotificationsList {
  @service currentUser;
  @service siteSettings;
  @service site;

  get dismissTypes() {
    return this.filterByTypes;
  }

  dismissWarningModal() {
    return null;
  }
}
