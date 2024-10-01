import {
  buttonDetails,
  NotificationLevels,
} from "discourse/lib/notification-levels";

export const threadNotificationButtonLevels = [
  NotificationLevels.WATCHING,
  NotificationLevels.TRACKING,
  NotificationLevels.REGULAR,
].map(buttonDetails);
