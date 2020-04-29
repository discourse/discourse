import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  classNames: ["notifications-filter"],
  content: [
    {
      type: "all",
      value: I18n.t("user.user_notifications.filters.all")
    },
    {
      type: "read",
      value: I18n.t("user.user_notifications.filters.read")
    },
    {
      type: "unread",
      value: I18n.t("user.user_notifications.filters.unread")
    }
  ],
  value: {
    type: "all",
    value: I18n.t("user.user_notifications.filters.all")
  },
  isVisible: true,
  valueProperty: null,
  nameProperty: "value",
  selectKitOptions: {
    headerComponent: "notifications-filter/notifications-filter-header"
  },

  actions: {
    onChange(filter) {
      this.set("value", filter);
      this.set("filter", filter.type);
    }
  }
});
