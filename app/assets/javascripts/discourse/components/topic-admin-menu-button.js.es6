import MountWidget from "discourse/components/mount-widget";
import optionalService from "discourse/lib/optional-service";

export default MountWidget.extend({
  classNames: "topic-admin-menu-button-container",
  tagName: "span",
  widget: "topic-admin-menu-button",
  adminTools: optionalService(),

  buildArgs() {
    return this.getProperties("topic", "fixed", "openUpwards", "rightSide");
  },

  showModerationHistory() {
    this.get("adminTools").showModerationHistory({
      filter: "topic",
      topic_id: this.get("topic.id")
    });
  }
});
