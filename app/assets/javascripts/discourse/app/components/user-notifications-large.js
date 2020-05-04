import MountWidget from "discourse/components/mount-widget";

export default MountWidget.extend({
  widget: "user-notifications-large",
  notifications: null,
  filter: null,
  args: null,

  didReceiveAttrs() {
    this._super(...arguments);

    this.set("args", {
      notifications: this.notifications,
      filter: this.filter
    });

    this.queueRerender();
  }
});
