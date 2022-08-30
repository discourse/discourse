import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";

export default class UserMenuLikesNotificationsList extends UserMenuNotificationsList {
  get filterByTypes() {
    // TODO(osama): reaction is a type used by the reactions plugin, but it's
    // added here temporarily unitl we add a plugin API for extending
    // filterByTypes in lists
    return ["liked", "liked_consolidated", "reaction"];
  }

  get dismissTypes() {
    return this.filterByTypes;
  }

  dismissWarningModal() {
    return null;
  }
}
