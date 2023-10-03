import {
  NotificationLevels,
  buttonDetails,
} from "discourse/lib/notification-levels";

export const threadNotificationButtonLevels = [
  NotificationLevels.TRACKING,
  NotificationLevels.REGULAR,
].map(buttonDetails);
