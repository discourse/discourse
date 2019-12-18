import MountWidget from "discourse/components/mount-widget";

export default MountWidget.extend({
  classNames: "topic-admin-menu-button-container",
  tagName: "span",
  widget: "topic-admin-menu-button",

  buildArgs() {
    return this.getProperties("topic", "fixed", "openUpwards", "rightSide");
  }
});
