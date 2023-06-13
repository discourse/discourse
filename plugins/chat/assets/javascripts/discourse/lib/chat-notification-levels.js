import {
  NotificationLevels,
  buttonDetails,
} from "discourse/lib/notification-levels";

export const threadLevels = [
  NotificationLevels.TRACKING,
  NotificationLevels.REGULAR,
].map(buttonDetails);
