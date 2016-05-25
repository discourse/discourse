const NotificationLevels = {
  WATCHING: 3,
  TRACKING: 2,
  REGULAR: 1,
  MUTED: 0
};
export default NotificationLevels;

export function buttonDetails(level) {
  switch(level) {
    case NotificationLevels.WATCHING:
      return { id: NotificationLevels.WATCHING, key: 'watching', icon: 'exclamation-circle' };
    case NotificationLevels.TRACKING:
      return { id: NotificationLevels.TRACKING, key: 'tracking', icon: 'circle' };
    case NotificationLevels.MUTED:
      return { id: NotificationLevels.MUTED, key: 'muted', icon: 'times-circle' };
    default:
      return { id: NotificationLevels.REGULAR, key: 'regular', icon: 'circle-o' };
  }
}
export const all = [ NotificationLevels.WATCHING,
                     NotificationLevels.TRACKING,
                     NotificationLevels.MUTED,
                     NotificationLevels.DEFAULT ].map(buttonDetails);
