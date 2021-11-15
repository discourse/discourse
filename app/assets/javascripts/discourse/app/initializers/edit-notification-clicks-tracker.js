import { setLastEditNotificationClick } from "discourse/models/post-stream";

export default {
  name: "edit-notification-clicks-tracker",

  initialize(container) {
    const appEvents = container.lookup("service:app-events");
    appEvents.on("edit-notification:clicked", this.handleClick);
  },

  handleClick({ topicId, postNumber, revisionNumber }) {
    setLastEditNotificationClick(topicId, postNumber, revisionNumber);
  },
};
