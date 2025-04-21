import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { selectKitOptions } from "select-kit/components/select-kit";

@classNames("notifications-filter")
@selectKitOptions({
  headerComponent: "notifications-filter/notifications-filter-header",
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
