import NotificationOptionsComponent from "select-box-kit/components/notifications-button";

export default NotificationOptionsComponent.extend({
  classNames: "tag-notifications-button",
  i18nPrefix: "tagging.notifications",
  showFullTitle: false,
  headerComponent: "tag-notifications-button/tag-notifications-button-header",

  actions: {
    onSelect(value) {
      value = this.defaultOnSelect(value);
      this.sendAction("action", value);
      this.blur();
    }
  }
});
