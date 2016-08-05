const MUTED = 0;
const REGULAR = 1;
const TRACKING = 2;
const WATCHING = 3;
const WATCHING_FIRST_POST = 4;

export const NotificationLevels = { WATCHING_FIRST_POST, WATCHING, TRACKING, REGULAR, MUTED };

export function buttonDetails(level) {
  switch(level) {
    case WATCHING_FIRST_POST:
      return { id: WATCHING_FIRST_POST, key: 'watching_first_post', icon: 'dot-circle-o' };
    case WATCHING:
      return { id: WATCHING, key: 'watching', icon: 'exclamation-circle' };
    case TRACKING:
      return { id: TRACKING, key: 'tracking', icon: 'circle' };
    case MUTED:
      return { id: MUTED, key: 'muted', icon: 'times-circle' };
    default:
      return { id: REGULAR, key: 'regular', icon: 'circle-o' };
  }
}

export const allLevels = [ WATCHING, TRACKING, WATCHING_FIRST_POST, REGULAR, MUTED ].map(buttonDetails);
export const topicLevels = allLevels.filter(l => l.id !== WATCHING_FIRST_POST);
