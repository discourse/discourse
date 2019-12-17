import MountWidget from "discourse/components/mount-widget";

export default MountWidget.extend({
  classNames: "topic-admin-menu-button-container",
  tagName: "span",
  widget: "topic-admin-menu-button",

  buildArgs() {
    return this.getProperties("topic", "fixed", "openUpwards", "rightSide");
  },

  toggleAdminMenu() {
    $(".toggle-admin-menu")
      .first()
      .click();
  },

  didInsertElement() {
    this._super(...arguments);

    this.appEvents.on("topic:toggleAdminMenu", this, this.toggleAdminMenu);
  },

  willDestroyElement() {
    this._super(...arguments);

    this.appEvents.off("topic:toggleAdminMenu", this, this.toggleAdminMenu);
  }
});
