import { setLastEditNotificationClick } from "discourse/models/post-stream";

export default {
  name: "edit-notification-clicks-tracker",

  initialize(container) {
    container
      .lookup("service:app-events")
      .on(
        "edit-notification:clicked",
        ({ topicId, postNumber, revisionNumber }) => {
          setLastEditNotificationClick(topicId, postNumber, revisionNumber);
        }
      );
  },
};
