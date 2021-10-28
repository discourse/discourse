import { setLastEditNotificationClick } from "discourse/models/post-stream";

export default {
  name: "edit-notification-clicks-tracker",

  initialize(container) {
    this.appEvents = container.lookup("service:app-events");
    this.appEvents.on("edit-notification:clicked", this, this.handleClick);
  },

  handleClick({ topicId, postNumber, revisionNumber }) {
    setLastEditNotificationClick(topicId, postNumber, revisionNumber);
  },

  teardown() {
    this.appEvents.off("edit-notification:clicked", this, this.handleClick);
  },
};
