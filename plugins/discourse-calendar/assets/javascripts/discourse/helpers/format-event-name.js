import { i18n } from "discourse-i18n";

function sameTimezoneOffset(timezone1, timezone2) {
  if (!timezone1 || !timezone2) {
    return false;
  }

  const offset1 = moment.tz(timezone1).utcOffset();
  const offset2 = moment.tz(timezone2).utcOffset();
  return offset1 === offset2;
}

export function formatEventName(event, userTimezone) {
  let output = event.name || event.post.topic.title;

  if (
    event.showLocalTime &&
    event.timezone &&
    !sameTimezoneOffset(event.timezone, userTimezone)
  ) {
    output +=
      ` (${i18n("discourse_calendar.local_time")}: ` +
      moment(event.startsAt).tz(event.timezone).format("H:mma") +
      ")";
  }

  return output;
}
