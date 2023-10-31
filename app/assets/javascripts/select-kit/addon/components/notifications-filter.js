import { computed } from "@ember/object";
import I18n from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  classNames: ["notifications-filter"],
  nameProperty: "label",

  content: computed(function () {
    return [
      {
        id: "all",
        label: I18n.t("user.user_notifications.filters.all"),
      },
      {
        id: "read",
        label: I18n.t("user.user_notifications.filters.read"),
      },
      {
        id: "unread",
        label: I18n.t("user.user_notifications.filters.unread"),
      },
    ];
  }),

  selectKitOptions: {
    headerComponent: "notifications-filter/notifications-filter-header",
  },
});
