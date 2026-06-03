import { i18n } from "discourse-i18n";
import { isEqualZones } from "discourse/plugins/discourse-local-dates/lib/local-date-builder";

export function formatEventName(event, userTimezone) {
  let output = event.name || event.post.topic.title;

  if (
    event.showLocalTime &&
    event.timezone &&
    !isEqualZones(event.timezone, userTimezone)
  ) {
    output += ` (${i18n("discourse_calendar.local_time")})`;
  }

  return output;
}
