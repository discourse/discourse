import I18n from "I18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { computed } from "@ember/object";

export default DropdownSelectBoxComponent.extend({
  classNames: ["notifications-filter"],

  content: computed(function() {
    return [
      {
        id: "all",
        label: I18n.t("user.user_notifications.filters.all")
      },
      {
        id: "read",
        label: I18n.t("user.user_notifications.filters.read")
      },
      {
        id: "unread",
        label: I18n.t("user.user_notifications.filters.unread")
      }
    ];
  }),

  selectKitOptions: {
    headerComponent: "notifications-filter/notifications-filter-header"
  }
});
