import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import DropdownSelectBoxComponent from "discourse/select-kit/components/dropdown-select-box";
import { selectKitOptions } from "discourse/select-kit/components/select-kit";
import { i18n } from "discourse-i18n";
import NotificationsFilterHeader from "./notifications-filter/notifications-filter-header";

@classNames("notifications-filter")
@selectKitOptions({
  headerComponent: NotificationsFilterHeader,
})
export default class NotificationsFilter extends DropdownSelectBoxComponent {
  nameProperty = "label";

  @computed
  get content() {
    return [
      {
        id: "all",
        label: i18n("user.user_notifications.filters.all"),
      },
      {
        id: "read",
        label: i18n("user.user_notifications.filters.read"),
      },
      {
        id: "unread",
        label: i18n("user.user_notifications.filters.unread"),
      },
    ];
  }
}
